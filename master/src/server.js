const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const mqtt = require('mqtt');
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');

const app = express();
const server = http.createServer(app);
const io = socketIO(server);

// Configuración
const MQTT_BROKER = process.env.MQTT_BROKER || 'mqtt://mosquitto:1883';
const GRPC_PORT = process.env.GRPC_PORT || '50051';
const WEB_PORT = process.env.WEB_PORT || '8888';
const MASTER_HOST = process.env.MASTER_HOST || 'master';

// Cargar configuración de API Keys
let apiKeysConfig = { keys: [], distribution: { strategy: 'round-robin' } };
let enabledKeys = [];
let currentKeyIndex = 0;

function loadApiKeys() {
  try {
    const configPath = path.join(__dirname, '../../config/api_keys.json');
    const configData = fs.readFileSync(configPath, 'utf8');
    apiKeysConfig = JSON.parse(configData);
    
    // Filtrar solo las keys habilitadas
    enabledKeys = apiKeysConfig.keys.filter(k => k.enabled === true);
    
    if (enabledKeys.length === 0) {
      console.warn('[CONFIG] ⚠️  No hay API keys habilitadas en config/api_keys.json');
      console.warn('[CONFIG] ⚠️  Usando API key de variable de entorno si está disponible');
      if (process.env.GEMINI_API_KEY) {
        enabledKeys = [{
          id: 'env_key',
          provider: 'gemini',
          key: process.env.GEMINI_API_KEY,
          owner: 'Environment Variable',
          enabled: true
        }];
      }
    } else {
      console.log(`[CONFIG] ✅ Cargadas ${enabledKeys.length} API keys:`);
      enabledKeys.forEach((k, i) => {
        console.log(`[CONFIG]    ${i + 1}. ${k.id} (${k.provider}) - Owner: ${k.owner}`);
      });
      console.log(`[CONFIG] 📊 Estrategia de distribución: ${apiKeysConfig.distribution.strategy}`);
    }
  } catch (error) {
    console.error('[CONFIG] ❌ Error al cargar config/api_keys.json:', error.message);
    console.warn('[CONFIG] ⚠️  Usando API key de variable de entorno si está disponible');
    if (process.env.GEMINI_API_KEY) {
      enabledKeys = [{
        id: 'env_key',
        provider: 'gemini',
        key: process.env.GEMINI_API_KEY,
        owner: 'Environment Variable',
        enabled: true
      }];
    }
  }
}

// Obtener la siguiente API key según estrategia
function getNextApiKey() {
  if (enabledKeys.length === 0) {
    console.warn('[CONFIG] ⚠️  No hay API keys disponibles');
    return '';
  }

  const strategy = apiKeysConfig.distribution?.strategy || 'round-robin';
  
  let selectedKey;
  switch (strategy) {
    case 'random':
      const randomIndex = Math.floor(Math.random() * enabledKeys.length);
      selectedKey = enabledKeys[randomIndex];
      break;
    
    case 'round-robin':
    default:
      selectedKey = enabledKeys[currentKeyIndex % enabledKeys.length];
      currentKeyIndex++;
      break;
  }
  
  console.log(`[CONFIG] 🔑 Usando API key: ${selectedKey.id} (${selectedKey.owner})`);
  return selectedKey.key;
}

// Cargar keys al iniciar
loadApiKeys();

// Cargar proto de gRPC
const PROTO_PATH = path.join(__dirname, '../../proto/worker.proto');
const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true
});
const workerProto = grpc.loadPackageDefinition(packageDefinition).worker;

// Estado del sistema
const workers = new Map(); // workerId -> { status, lastSeen }
const pendingTasks = []; // Cola de tareas pendientes
const activeTasks = new Map(); // taskId -> { workerId, sessionId, query, timestamp }
const sessions = new Map(); // sessionId -> socket

// Cliente MQTT
let mqttClient;

// Servidor gRPC para recibir callbacks
function startGRPCServer() {
  const grpcServer = new grpc.Server();
  
  grpcServer.addService(workerProto.WorkerCallback.service, {
    SendResult: (call, callback) => {
      const result = call.request;
      console.log(`[GRPC] Resultado recibido del worker ${result.worker_id}`);
      
      // Log en MQTT
      publishLog(`Master recibió resultado de worker ${result.worker_id} para sesión ${result.session_id}`);
      
      // Buscar la tarea activa
      const taskId = `${result.session_id}_${result.query_timestamp}`;
      if (activeTasks.has(taskId)) {
        activeTasks.delete(taskId);
      }
      
      // Enviar resultado al cliente web
      const socket = sessions.get(result.session_id);
      if (socket) {
        socket.emit('ai-response', {
          query: result.original_query,
          response: result.ai_response,
          workerId: result.worker_id,
          processingTime: result.processing_time_ms,
          timestamp: result.completion_timestamp
        });
      }
      
      // Marcar worker como disponible
      if (workers.has(result.worker_id)) {
        workers.get(result.worker_id).status = 'idle';
      }
      
      // Asignar siguiente tarea si hay pendientes
      assignNextTask();
      
      callback(null, { success: true, message: 'Resultado recibido correctamente' });
    }
  });
  
  grpcServer.bindAsync(
    `0.0.0.0:${GRPC_PORT}`,
    grpc.ServerCredentials.createInsecure(),
    (err, port) => {
      if (err) {
        console.error('[GRPC] Error al iniciar servidor:', err);
        return;
      }
      console.log(`[GRPC] Servidor escuchando en puerto ${port}`);
      grpcServer.start();
    }
  );
}

// Conectar a MQTT
function connectMQTT() {
  mqttClient = mqtt.connect(MQTT_BROKER);
  
  mqttClient.on('connect', () => {
    console.log('[MQTT] Conectado al broker');
    publishLog('Master conectado al broker MQTT');
    
    // Suscribirse a tópicos
    mqttClient.subscribe('upb/workers/register', (err) => {
      if (err) console.error('[MQTT] Error al suscribirse a register:', err);
    });
    
    mqttClient.subscribe('upb/workers/status', (err) => {
      if (err) console.error('[MQTT] Error al suscribirse a status:', err);
    });
    
    mqttClient.subscribe('upb/logs', (err) => {
      if (err) console.error('[MQTT] Error al suscribirse a logs:', err);
    });
  });
  
  mqttClient.on('message', (topic, message) => {
    const data = JSON.parse(message.toString());
    
    if (topic === 'upb/workers/register') {
      handleWorkerRegistration(data);
    } else if (topic === 'upb/workers/status') {
      handleWorkerStatus(data);
    } else if (topic === 'upb/logs') {
      console.log(`[LOG] ${data.message}`);
    }
  });
  
  mqttClient.on('error', (err) => {
    console.error('[MQTT] Error:', err);
  });
}

// Manejar registro de workers
function handleWorkerRegistration(data) {
  const { worker_id, language, status } = data;
  console.log(`[WORKER] Registrado: ${worker_id} (${language})`);
  
  workers.set(worker_id, {
    language,
    status: status || 'idle',
    lastSeen: Date.now()
  });
  
  publishLog(`Worker ${worker_id} (${language}) registrado y disponible`);
  
  // Asignar tarea si hay pendientes
  assignNextTask();
}

// Manejar estado de workers
function handleWorkerStatus(data) {
  const { worker_id, status } = data;
  
  if (workers.has(worker_id)) {
    workers.get(worker_id).status = status;
    workers.get(worker_id).lastSeen = Date.now();
    
    if (status === 'idle') {
      console.log(`[WORKER] ${worker_id} disponible`);
      assignNextTask();
    }
  }
}

// Asignar siguiente tarea
function assignNextTask() {
  if (pendingTasks.length === 0) return;
  
  // Buscar worker disponible
  for (const [workerId, worker] of workers.entries()) {
    if (worker.status === 'idle' && pendingTasks.length > 0) {
      const task = pendingTasks.shift();
      assignTaskToWorker(workerId, task);
      break;
    }
  }
}

// Asignar tarea a worker específico
function assignTaskToWorker(workerId, task) {
  workers.get(workerId).status = 'busy';
  
  // Si el usuario no proporcionó API key, usar del pool
  const apiKey = task.apiKey || getNextApiKey();
  
  const taskMessage = {
    worker_id: workerId,
    session_id: task.sessionId,
    query: task.query,
    api_key: apiKey,
    grpc_endpoint: `${MASTER_HOST}:${GRPC_PORT}`,
    timestamp: task.timestamp
  };
  
  const taskId = `${task.sessionId}_${task.timestamp}`;
  activeTasks.set(taskId, {
    workerId,
    sessionId: task.sessionId,
    query: task.query,
    timestamp: task.timestamp
  });
  
  console.log(`[TASK] Asignando tarea a worker ${workerId}`);
  publishLog(`Master asignó tarea a worker ${workerId} para sesión ${task.sessionId}`);
  
  mqttClient.publish(
    `upb/workers/${workerId}/tasks`,
    JSON.stringify(taskMessage)
  );
}

// Publicar log en MQTT
function publishLog(message) {
  if (mqttClient && mqttClient.connected) {
    mqttClient.publish('upb/logs', JSON.stringify({
      timestamp: Date.now(),
      source: 'master',
      message
    }));
  }
}

// Configurar rutas web
app.use(express.static(path.join(__dirname, '../public')));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

// Socket.IO para comunicación con clientes web
io.on('connection', (socket) => {
  const sessionId = uuidv4();
  sessions.set(sessionId, socket);
  
  console.log(`[WEB] Nueva sesión: ${sessionId}`);
  publishLog(`Nueva sesión web conectada: ${sessionId}`);
  socket.on('user-query', (data) => {
    const { query, apiKey } = data;
    console.log(`[QUERY] Sesión ${sessionId}: ${query}`);
    
    const task = {
      sessionId,
      query,
      apiKey: apiKey || '', // Si está vacío, se usará del pool en assignTaskToWorker
      timestamp: Date.now()
    };query,
      apiKey: apiKey || process.env.GEMINI_API_KEY || '',
      timestamp: Date.now()
    };
    
    publishLog(`Master recibió query de sesión ${sessionId}`);
    
    // Intentar asignar inmediatamente o agregar a cola
    let assigned = false;
    for (const [workerId, worker] of workers.entries()) {
      if (worker.status === 'idle') {
        assignTaskToWorker(workerId, task);
        assigned = true;
        break;
      }
    }
    
    if (!assigned) {
      pendingTasks.push(task);
      console.log(`[QUEUE] Tarea agregada a cola. Pendientes: ${pendingTasks.length}`);
      socket.emit('task-queued', { position: pendingTasks.length });
    }
  });
  
  socket.on('disconnect', () => {
    sessions.delete(sessionId);
    console.log(`[WEB] Sesión desconectada: ${sessionId}`);
    publishLog(`Sesión web desconectada: ${sessionId}`);
  });
});

// Iniciar servidor
function start() {
  startGRPCServer();
  connectMQTT();
  
  server.listen(WEB_PORT, '0.0.0.0', () => {
    console.log(`[WEB] Servidor web escuchando en puerto ${WEB_PORT}`);
    publishLog(`Master iniciado en puerto ${WEB_PORT}`);
  });
}

// Esperar un momento antes de iniciar (para que MQTT esté listo)
setTimeout(start, 3000);
