# Troubleshooting y Mejoras Futuras

## 🔧 Problemas Comunes y Soluciones

### 1. Workers no se registran con el Master

**Síntomas:**
- No aparecen mensajes de "Worker registrado" en logs del Master
- Tareas quedan en cola indefinidamente
- Comando `docker service logs ai-system_worker-python` muestra errores de conexión

**Causas Posibles:**
- Mosquitto no está listo cuando los workers inician
- Problemas de red entre contenedores
- Workers iniciando antes que el Master

**Soluciones:**
```bash
# 1. Verificar que Mosquitto esté corriendo
docker service ps ai-system_mosquitto

# 2. Ver logs de Mosquitto
docker service logs ai-system_mosquitto

# 3. Verificar conectividad de red
docker network inspect ai-system_ai-network

# 4. Reiniciar stack completo
./stop.sh
sleep 15
./deploy.sh

# 5. Aumentar el delay de inicio en workers
# Editar Dockerfiles: aumentar sleep de 5 a 10 segundos
```

### 2. Error "Failed to connect to gRPC server"

**Síntomas:**
- Workers completan tareas pero no envían resultados
- Logs muestran "Error al enviar resultado via gRPC"
- Usuario no recibe respuesta

**Causas Posibles:**
- Master no está escuchando en puerto gRPC
- Firewall bloqueando puerto 50051
- Endpoint gRPC incorrecto en la tarea

**Soluciones:**
```bash
# 1. Verificar que Master está escuchando en gRPC
docker service logs ai-system_master | grep "GRPC.*50051"

# 2. Verificar que el puerto está expuesto
docker service inspect ai-system_master | grep -A 5 Ports

# 3. Probar conectividad desde worker a master
docker exec -it <worker-container-id> nc -zv master 50051

# 4. Revisar el endpoint en los logs
docker service logs ai-system_worker-python | grep "grpc_endpoint"
```

### 3. Error de API Key de Gemini

**Síntomas:**
- Worker procesa tarea pero respuesta es "Error: ..."
- Logs muestran "401 Unauthorized" o "403 Forbidden"
- Mensaje de "API key not valid"

**Causas Posibles:**
- API Key incorrecta o expirada
- API Key sin permisos para Gemini
- Límite de tasa excedido

**Soluciones:**
```bash
# 1. Verificar API Key manualmente
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"test"}]}]}'

# 2. Generar nueva API Key
# Ir a https://aistudio.google.com/api-keys

# 3. Verificar límites
# Revisar dashboard de Google Cloud Console

# 4. Usar diferentes API Keys para diferentes workers
# Configurar como variables de entorno en docker-compose.yml
```

### 4. Build de imagen de Go falla

**Síntomas:**
- `./build.sh` falla en worker-go
- Error "cannot find package"
- Error en protoc

**Soluciones:**
```bash
# 1. Limpiar módulos de Go
cd worker-go
rm -rf go.sum
go mod tidy
go mod download

# 2. Verificar que proto está disponible
ls -la ../proto/worker.proto

# 3. Build manual para debugging
docker build -t test-go ./worker-go --progress=plain

# 4. Verificar versión de Go en Dockerfile
# Usar go 1.21 o superior
```

### 5. Build de imagen de Java falla

**Síntomas:**
- Maven no puede descargar dependencias
- Error en compilación de proto
- OutOfMemory durante build

**Soluciones:**
```bash
# 1. Aumentar memoria para Maven
# En worker-java/Dockerfile, agregar:
# ENV MAVEN_OPTS="-Xmx1024m"

# 2. Build local primero
cd worker-java
mvn clean package -DskipTests

# 3. Verificar proto
mvn protobuf:compile

# 4. Limpiar caché de Maven
rm -rf ~/.m2/repository
```

### 6. Web App no carga

**Síntomas:**
- Browser muestra "Connection refused"
- Timeout al acceder a http://10.1.2.166:31663
- 502 Bad Gateway

**Soluciones:**
```bash
# 1. Verificar que Master está corriendo
docker service ps ai-system_master

# 2. Verificar logs del Master
docker service logs ai-system_master | tail -50

# 3. Verificar puerto mapeado
docker service inspect ai-system_master | grep PublishedPort

# 4. Probar desde el servidor
curl http://localhost:31663

# 5. Verificar firewall
sudo ufw status
sudo iptables -L -n | grep 31663
```

### 7. Socket.IO desconecta constantemente

**Síntomas:**
- Browser muestra "Desconectado" repetidamente
- Sesiones se pierden
- No se pueden enviar consultas

**Soluciones:**
```bash
# 1. Verificar logs de Socket.IO
docker service logs ai-system_master | grep "Socket.IO"

# 2. Aumentar timeout en master/src/server.js
# En las opciones de Socket.IO, agregar:
# pingTimeout: 60000,
# pingInterval: 25000

# 3. Verificar proxy/load balancer
# Si hay uno, configurar sticky sessions
```

### 8. Mosquitto no acepta conexiones

**Síntomas:**
- Workers no pueden conectarse a MQTT
- Error "Connection refused" en puerto 1883
- Master no puede publicar mensajes

**Soluciones:**
```bash
# 1. Verificar configuración de Mosquitto
cat mosquitto/config/mosquitto.conf

# 2. Verificar permisos de directorios
ls -la mosquitto/data
chmod -R 777 mosquitto/

# 3. Verificar logs de Mosquitto
docker service logs ai-system_mosquitto

# 4. Reiniciar solo Mosquitto
docker service update --force ai-system_mosquitto
```

### 9. Tareas quedan en cola indefinidamente

**Síntomas:**
- Contador de tareas pendientes aumenta
- Workers muestran estado "idle" pero no reciben tareas
- Logs muestran "Tarea agregada a cola"

**Soluciones:**
```bash
# 1. Verificar que workers están suscritos
docker service logs ai-system_worker-python | grep "Suscrito"

# 2. Verificar tópicos MQTT
mosquitto_sub -h 10.1.2.166 -p 21662 -t "upb/workers/+/tasks" -v

# 3. Reiniciar Master (reinicia lógica de cola)
docker service update --force ai-system_master

# 4. Verificar estado de workers en Master
docker service logs ai-system_master | grep "status"
```

### 10. Alta latencia en respuestas

**Síntomas:**
- Respuestas tardan más de 20 segundos
- Procesamiento más lento de lo esperado

**Soluciones:**
```bash
# 1. Verificar carga del sistema
docker stats

# 2. Verificar latencia de red
ping 10.1.2.166

# 3. Escalar workers
./scale.sh worker-python 10

# 4. Verificar API de Gemini
# Puede estar experimentando latencia

# 5. Reducir simulación en workers
# Cambiar sleep de 10s a 5s para testing
```

## 🚀 Mejoras Futuras

### Corto Plazo (1-2 semanas)

#### 1. Dashboard de Monitoreo
```
Implementar:
- Panel web con métricas en tiempo real
- Gráficos de tareas procesadas
- Estado de workers (idle/busy)
- Tiempos de respuesta promedio
- Uso de recursos

Tecnologías: Grafana + Prometheus
```

#### 2. Autenticación en MQTT
```
mosquitto_passwd -c /mosquitto/config/passwd username
# Actualizar mosquitto.conf:
allow_anonymous false
password_file /mosquitto/config/passwd
```

#### 3. TLS para gRPC
```
Generar certificados:
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365

Actualizar gRPC server y clients para usar SSL
```

#### 4. Rate Limiting
```javascript
// En master/src/server.js
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 100 // límite de 100 requests
});

app.use('/api/', limiter);
```

#### 5. Persistencia de Tareas
```javascript
// Agregar Redis o MongoDB para persistir:
- Cola de tareas
- Historial de consultas
- Resultados anteriores
- Estado de workers
```

### Mediano Plazo (1-2 meses)

#### 6. Sistema de Prioridades
```javascript
// Tareas con diferentes prioridades
{
  priority: 'high' | 'normal' | 'low',
  // Procesar high primero
}
```

#### 7. Múltiples Modelos de IA
```python
# Soportar diferentes modelos
models = {
  'gemini-pro': genai.GenerativeModel('gemini-pro'),
  'gemini-pro-vision': genai.GenerativeModel('gemini-pro-vision'),
  'gpt-4': openai_client  # Agregar OpenAI
}
```

#### 8. Retry Logic
```python
# En workers, reintentar en caso de fallo
max_retries = 3
for attempt in range(max_retries):
    try:
        result = query_gemini(query, api_key)
        break
    except Exception as e:
        if attempt == max_retries - 1:
            raise
        time.sleep(2 ** attempt)  # Exponential backoff
```

#### 9. Métricas Detalladas
```
Implementar:
- Tiempo promedio por worker
- Tasa de éxito/fallo
- Uso de API Keys
- Distribución de carga
- Histogramas de latencia

Tecnología: Prometheus + Grafana
```

#### 10. Health Checks
```yaml
# En docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8888/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Largo Plazo (3-6 meses)

#### 11. Kubernetes Migration
```
Migrar de Docker Swarm a Kubernetes:
- Mayor escalabilidad
- Mejor orchestration
- Ecosistema más amplio
- Service mesh (Istio)
```

#### 12. API REST Completa
```javascript
// Endpoints adicionales
GET  /api/tasks          // Listar tareas
GET  /api/tasks/:id      // Estado de tarea
GET  /api/workers        // Listar workers
GET  /api/stats          // Estadísticas
POST /api/tasks          // Crear tarea
```

#### 13. Streaming de Respuestas
```javascript
// Socket.IO streaming
socket.on('ai-response-chunk', (chunk) => {
  // Mostrar respuesta incremental
  appendToResponse(chunk);
});
```

#### 14. Multi-Tenancy
```
Implementar:
- Múltiples organizaciones
- Aislamiento de datos
- Quotas por tenant
- Billing por uso
```

#### 15. Machine Learning para Load Balancing
```python
# Predecir carga y asignar tareas inteligentemente
- Historial de tiempos de workers
- Complejidad estimada de query
- Asignación óptima
```

## 🎯 Optimizaciones de Performance

### 1. Caching de Respuestas
```javascript
// Redis cache para queries repetidos
const cached = await redis.get(queryHash);
if (cached) return cached;
```

### 2. Connection Pooling
```python
# Pool de conexiones gRPC
channel = grpc.insecure_channel(
    endpoint,
    options=[
        ('grpc.max_connection_idle_ms', 60000),
        ('grpc.keepalive_time_ms', 30000),
    ]
)
```

### 3. Batch Processing
```javascript
// Procesar múltiples queries en un worker
const batch = pendingTasks.splice(0, 5);
await Promise.all(batch.map(processBatch));
```

### 4. CDN para Web App
```
Servir assets estáticos desde CDN:
- HTML/CSS/JS minificados
- Imágenes optimizadas
- Lazy loading
```

## 📊 Métricas a Implementar

```javascript
// Estructura de métricas
{
  system: {
    uptime: number,
    total_tasks: number,
    active_workers: number,
    queue_length: number
  },
  performance: {
    avg_response_time: number,
    p95_response_time: number,
    p99_response_time: number,
    throughput: number  // tasks/minute
  },
  errors: {
    total_errors: number,
    error_rate: number,
    last_error: string
  },
  workers: [{
    id: string,
    status: string,
    tasks_completed: number,
    avg_time: number,
    last_seen: timestamp
  }]
}
```

## 🔒 Seguridad Adicional

### 1. Secrets Management
```bash
# Docker secrets
echo "my_api_key" | docker secret create gemini_key -
docker service update --secret-add gemini_key ai-system_worker-python
```

### 2. Network Policies
```yaml
# Limitar comunicación entre servicios
networks:
  frontend:
    driver: overlay
  backend:
    driver: overlay
    internal: true  # Solo interno
```

### 3. Logging Seguro
```javascript
// No logear información sensible
const sanitizedLog = {
  ...logData,
  api_key: '***REDACTED***'
};
```

## 📝 Documentación Adicional

### APIs Internas
- Documentar todos los endpoints con OpenAPI/Swagger
- Ejemplos de requests/responses
- Códigos de error

### Runbooks
- Procedimientos de deployment
- Rollback procedures
- Disaster recovery
- Escalamiento de incidentes

### Training
- Onboarding para nuevos desarrolladores
- Video tutoriales
- Labs hands-on

---

Para reportar issues o contribuir:
- GitHub Issues
- Pull Requests
- Documentación en /docs
