# Resumen Ejecutivo del Proyecto

## 🎯 Objetivo
Implementar un sistema distribuido Master-Slave con Docker Swarm que procese consultas a Google Gemini AI de manera asíncrona, utilizando MQTT para distribución de tareas y gRPC para callbacks.

## 📊 Componentes Implementados

### 1. Master (Node.js)
- **Función:** Coordinador central del sistema
- **Tecnologías:** Express, Socket.IO, MQTT Client, gRPC Server
- **Responsabilidades:**
  - Interfaz web para usuarios
  - Gestión de sesiones con Socket.IO
  - Distribución de tareas via MQTT
  - Recepción de resultados via gRPC
  - Cola de tareas pendientes

### 2. Workers (Python, Go, Java)
- **Función:** Procesadores de tareas
- **Tecnologías:** 
  - Python: paho-mqtt, grpcio, google-generativeai
  - Go: paho.mqtt, grpc, genai
  - Java: Eclipse Paho, gRPC, OkHttp
- **Responsabilidades:**
  - Registro automático con el Master
  - Consumo de tareas desde MQTT
  - Consulta a Gemini API
  - Simulación de procesamiento largo (10s)
  - Callback de resultados via gRPC

### 3. Mosquitto MQTT
- **Función:** Broker de mensajería
- **Tecnologías:** Eclipse Mosquitto 2.0
- **Responsabilidades:**
  - Comunicación asíncrona
  - Pub/Sub de tareas y logs
  - Registro de workers

### 4. Docker Swarm
- **Función:** Orquestación de contenedores
- **Responsabilidades:**
  - Deployment distribuido
  - Escalamiento automático
  - Alta disponibilidad
  - Load balancing

## 🔄 Flujo de Datos

```
Usuario → Web App (Socket.IO) → Master
                                   ↓
                            Valida Workers
                                   ↓
                      [Worker Idle?] → Sí → Asigna Tarea (MQTT)
                           ↓ No              ↓
                      Cola Pendientes    Worker Recibe
                                             ↓
                                    Consulta Gemini
                                             ↓
                                    Simula 10s
                                             ↓
                                    Callback (gRPC) → Master
                                                         ↓
                                              Envía a Usuario (Socket.IO)
```

## 📈 Métricas del Sistema

### Capacidad
- **Usuarios Simultáneos:** Ilimitado (limitado por recursos)
- **Workers por Lenguaje:** Configurable (default: 2 de cada uno)
- **Tareas Concurrentes:** = Número total de workers
- **Cola de Tareas:** Sin límite

### Performance
- **Tiempo de Registro Worker:** 3-5 segundos
- **Latencia MQTT:** < 100ms
- **Latencia gRPC:** < 1 segundo
- **Tiempo Total por Tarea:** ~10-15 segundos
  - Gemini API: 1-5s
  - Simulación: 10s
  - Overhead: < 1s

### Escalabilidad
- **Horizontal:** ✅ Agregar más workers
- **Vertical:** ✅ Más recursos por worker
- **Multi-Nodo:** ✅ Swarm soporta múltiples VMs
- **Auto-Recovery:** ✅ Swarm reinicia contenedores caídos

## 🏗️ Arquitectura de Deployment

```
Cluster Node (10.1.2.166)
│
├── Docker Swarm Manager
│   │
│   ├── Stack: ai-system
│   │   │
│   │   ├── Service: mosquitto (1 replica)
│   │   │   └── Port: 21662 → 1883
│   │   │
│   │   ├── Service: master (1 replica)
│   │   │   ├── Port: 31663 → 8888 (Web)
│   │   │   └── Port: 50051 (gRPC)
│   │   │
│   │   ├── Service: worker-python (2+ replicas)
│   │   │
│   │   ├── Service: worker-go (2+ replicas)
│   │   │
│   │   └── Service: worker-java (2+ replicas)
│   │
│   └── Network: ai-network (overlay)
│
└── Registry (10.1.2.166:5000)
    ├── master:latest
    ├── worker-python:latest
    ├── worker-go:latest
    └── worker-java:latest
```

## 🔐 Seguridad Implementada

- ✅ Variables de entorno para configuración
- ✅ API Keys no hardcodeadas
- ✅ Red overlay aislada
- ⚠️ MQTT sin autenticación (apropiado para desarrollo)
- ⚠️ gRPC sin TLS (apropiado para red interna)

## 📝 Formato de Mensajes

### Tarea (Master → Worker via MQTT)
```json
{
  "worker_id": "python-worker-abc123",
  "session_id": "uuid-v4",
  "query": "Pregunta del usuario",
  "api_key": "AIza...",
  "grpc_endpoint": "master:50051",
  "timestamp": 1702345678901
}
```

### Resultado (Worker → Master via gRPC)
```protobuf
TaskResult {
  worker_id: string
  session_id: string
  original_query: string
  ai_response: string
  api_key: string
  processing_time_ms: int64
  query_timestamp: int64
  completion_timestamp: int64
}
```

### Log (Todos → MQTT upb/logs)
```json
{
  "timestamp": 1702345678901,
  "source": "worker-id | master",
  "message": "Descripción del evento"
}
```

## 🎨 Interfaz de Usuario

### Características
- ✅ Diseño moderno y responsivo
- ✅ Chat-like interface
- ✅ Estado de conexión en tiempo real
- ✅ Identificador de sesión único
- ✅ Input para API Key opcional
- ✅ Indicador de carga durante procesamiento
- ✅ Metadatos de respuesta (worker, tiempo)

### Tecnologías Web
- HTML5 + CSS3
- JavaScript vanilla
- Socket.IO client
- Gradientes y animaciones CSS

## 📦 Requisitos de Sistema

### Para Development
- Docker 20.10+
- Docker Compose 1.29+
- 4GB RAM mínimo
- 10GB espacio en disco

### Para Production
- Docker Swarm cluster
- 8GB RAM recomendado
- Multiple nodes recomendado
- Registry privado

## 🚀 Comandos Principales

```bash
# Build y Push
./build.sh

# Deploy
./deploy.sh

# Verificar
./verify.sh

# Monitorear
./monitor.sh

# Ver Logs
./logs.sh

# Escalar
./scale.sh worker-python 5

# Detener
./stop.sh
```

## 📊 KPIs del Sistema

### Disponibilidad
- **Target:** 99%+
- **Medición:** Uptime de servicios
- **Herramienta:** `docker service ps`

### Throughput
- **Target:** N tareas/minuto (N = workers activos)
- **Medición:** Logs de tareas completadas
- **Herramienta:** `grep "completó tarea"`

### Latencia
- **Target:** < 15s por tarea
- **Medición:** processing_time_ms en resultados
- **Herramienta:** Logs del Master

### Utilización
- **Target:** 70-80% workers busy en carga normal
- **Medición:** Status messages en MQTT
- **Herramienta:** `mosquitto_sub -t "upb/workers/status"`

## 🔧 Mantenimiento

### Actualizaciones
```bash
# Actualizar imagen de un servicio
docker service update --image 10.1.2.166:5000/master:latest ai-system_master

# Rolling update automático
docker service update --update-parallelism 1 --update-delay 10s ai-system_worker-python
```

### Backup
```bash
# Exportar configuración
docker stack config ai-system > backup-config.yml

# Backup de datos de Mosquitto
tar -czf mosquitto-backup.tar.gz mosquitto/data/
```

### Logs
```bash
# Retención de logs
docker service update --log-opt max-size=10m --log-opt max-file=3 ai-system_master
```

## 🎓 Aprendizajes Clave

### Arquitectura Distribuida
- ✅ Separación de responsabilidades
- ✅ Comunicación asíncrona
- ✅ Escalabilidad horizontal
- ✅ Tolerancia a fallos

### Tecnologías
- ✅ MQTT para pub/sub eficiente
- ✅ gRPC para RPCs tipadas
- ✅ Socket.IO para real-time web
- ✅ Docker Swarm para orquestación

### Interoperabilidad
- ✅ Workers en 3 lenguajes diferentes
- ✅ Protocolo común (gRPC + MQTT)
- ✅ Containerización unifica el deployment

## 📚 Referencias Técnicas

- Docker Swarm: https://docs.docker.com/engine/swarm/
- MQTT Protocol: https://mqtt.org/
- gRPC: https://grpc.io/
- Socket.IO: https://socket.io/
- Google Gemini: https://ai.google.dev/

## 👨‍💻 Autor

**Carlos Daniel Ochoa Molina**
- Universidad Privada Boliviana (UPB)
- Sistemas Distribuidos - Tercer Parcial
- Cluster Node: 10.1.2.166

## 📄 Licencia

Proyecto académico - UPB 2024
