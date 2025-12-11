# Sistema Distribuido Master/Slave con IA

## 📋 Descripción del Proyecto

Sistema distribuido de tipo Master-Slave implementado con **Docker Swarm** que permite realizar consultas a la API de **Google Gemini** de manera asíncrona. El sistema utiliza **MQTT** para la distribución de tareas a los Workers y **gRPC** para el envío de resultados mediante callbacks al Master.

### Componentes Principales

- **Master (NodeJS)**: Servidor web con Socket.IO, gestión de tareas, broker MQTT y servidor gRPC
- **Worker Python**: Procesador de tareas implementado en Python
- **Worker Go**: Procesador de tareas implementado en Go
- **Worker Java**: Procesador de tareas implementado en Java
- **Mosquitto**: Broker MQTT para comunicación asíncrona
- **Web App**: Interfaz de usuario tipo chat para interactuar con el sistema

## 🏗️ Arquitectura

```
┌─────────────┐
│ Web Browser │ (Socket.IO)
└──────┬──────┘
       │ 3XXX3
       ▼
┌──────────────────────────────────────────┐
│            Master (NodeJS)               │
│  ┌──────────┐  ┌────────┐  ┌─────────┐ │
│  │ Socket.IO│  │ gRPC   │  │  MQTT   │ │
│  │  Server  │  │ Server │  │ Client  │ │
│  └──────────┘  └────────┘  └─────────┘ │
└───────────┬──────────────────────────────┘
            │ MQTT (2XXX2)
            ▼
   ┌─────────────────┐
   │  Mosquitto MQTT │
   └────────┬────────┘
            │
    ┌───────┴───────┬───────────┐
    │               │           │
    ▼               ▼           ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Worker   │  │ Worker   │  │ Worker   │
│ (Python) │  │  (Go)    │  │ (Java)   │
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │
     └─────────────┴─────────────┘
              gRPC Callback
```

## 🚀 Características

- ✅ **Sistema Asíncrono**: Los usuarios no esperan la respuesta, se notifican cuando está lista
- ✅ **Multi-Worker**: 3 tipos de workers en diferentes lenguajes (Python, Go, Java)
- ✅ **Escalabilidad**: Fácil escalamiento de workers con Docker Swarm
- ✅ **Load Balancing**: Distribución automática de tareas entre workers disponibles
- ✅ **Múltiples Usuarios**: Soporte para múltiples sesiones simultáneas
- ✅ **Logging Centralizado**: Todos los eventos se registran en el tópico MQTT `upb/logs`
- ✅ **Simulación de Procesamiento**: 10 segundos de delay para simular procesamiento largo
- ✅ **Callbacks gRPC**: Comunicación eficiente entre Workers y Master

## 📁 Estructura del Proyecto

```
TPFinal_Sistemas_Distribuidos/
├── master/                      # Master Server (NodeJS)
│   ├── src/
│   │   └── server.js           # Servidor principal
│   ├── public/
│   │   └── index.html          # Web App
│   ├── package.json
│   └── Dockerfile
├── worker-python/               # Worker en Python
│   ├── worker.py
│   ├── requirements.txt
│   └── Dockerfile
├── worker-go/                   # Worker en Go
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── worker-java/                 # Worker en Java
│   ├── src/
│   │   └── main/java/upb/distribuidos/
│   │       └── Worker.java
│   ├── pom.xml
│   └── Dockerfile
├── proto/
│   └── worker.proto            # Definición gRPC
├── mosquitto/
│   └── config/
│       └── mosquitto.conf      # Configuración MQTT
├── docker-compose.yml          # Configuración de Swarm
├── build.sh                    # Script de construcción
├── deploy.sh                   # Script de despliegue
├── stop.sh                     # Script para detener
├── logs.sh                     # Ver logs
├── scale.sh                    # Escalar workers
├── monitor.sh                  # Monitoreo en tiempo real
└── README.md
```

## 🔧 Requisitos Previos

- Docker y Docker Compose instalados
- Docker Swarm inicializado
- Acceso al cluster con la información en `cluster_information.txt`
- API Keys de Google Gemini (https://aistudio.google.com/api-keys)

## 📦 Información del Cluster Asignado

```
Apellidos: OCHOA MOLINA
Nombres: CARLOS DANIEL
Node: 10.1.2.166
ssh(22): 11661
MQTT(1883): 21662
App(8888): 31663
```

## 🛠️ Instalación y Deployment

### 1. Inicializar Docker Swarm (si no está activo)

```bash
docker swarm init
```

### 2. Construir y Subir Imágenes al Registry

```bash
./build.sh
```

Este script:
- Construye las imágenes de Master y los 3 Workers
- Sube las imágenes al registry privado (10.1.2.166:5000)

### 3. Desplegar el Stack en Swarm

```bash
./deploy.sh
```

Este script:
- Crea los directorios necesarios
- Despliega todos los servicios en Docker Swarm
- Muestra el estado de los servicios

### 4. Acceder a la Aplicación

Abre tu navegador en:
```
http://10.1.2.166:31663
```

## 📖 Uso del Sistema

### Interfaz Web

1. **Conectar**: Al abrir la aplicación, se crea automáticamente una sesión
2. **API Key**: (Opcional) Ingresa tu API Key de Gemini en el campo superior
3. **Consulta**: Escribe tu pregunta en el campo de texto
4. **Enviar**: Presiona el botón "Enviar" o Enter
5. **Esperar**: La consulta se asigna a un worker disponible
6. **Respuesta**: Después de ~10 segundos, recibirás la respuesta de la IA

### Mensajes MQTT

El sistema utiliza los siguientes tópicos MQTT:

- `upb/workers/register`: Registro de nuevos workers
- `upb/workers/status`: Estado de workers (idle/busy)
- `upb/workers/{worker_id}/tasks`: Tareas asignadas a cada worker
- `upb/logs`: Logs centralizados del sistema

### Formato de Mensajes

**Tarea enviada al Worker (MQTT):**
```json
{
  "worker_id": "python-worker-abc123",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "query": "¿Qué es Docker Swarm?",
  "api_key": "AIza...",
  "grpc_endpoint": "master:50051",
  "timestamp": 1702345678901
}
```

**Resultado enviado al Master (gRPC):**
```protobuf
TaskResult {
  worker_id: "python-worker-abc123"
  session_id: "550e8400-e29b-41d4-a716-446655440000"
  original_query: "¿Qué es Docker Swarm?"
  ai_response: "Docker Swarm es..."
  api_key: "AIza..."
  processing_time_ms: 10245
  query_timestamp: 1702345678901
  completion_timestamp: 1702345689146
}
```

## 🔍 Comandos de Administración

### Ver Estado de Servicios

```bash
docker stack services ai-system
```

### Ver Logs

```bash
# Script interactivo
./logs.sh

# O directamente
docker service logs -f ai-system_master
docker service logs -f ai-system_worker-python
docker service logs -f ai-system_worker-go
docker service logs -f ai-system_worker-java
```

### Escalar Workers

```bash
# Escalar workers de Python a 5 réplicas
./scale.sh worker-python 5

# Escalar workers de Go a 3 réplicas
./scale.sh worker-go 3
```

### Monitorear el Sistema

```bash
./monitor.sh
```

Actualiza cada 5 segundos mostrando:
- Estado de los servicios
- Tareas/contenedores en ejecución
- Distribución en los nodos

### Detener el Sistema

```bash
./stop.sh
```

### Ver Tareas en Ejecución

```bash
docker stack ps ai-system
```

### Inspeccionar un Servicio

```bash
docker service inspect ai-system_master
docker service inspect ai-system_worker-python
```

## 🔬 Flujo de Procesamiento

1. **Usuario envía consulta** → Socket.IO → Master
2. **Master valida workers disponibles**
   - Si hay worker idle → Asigna tarea inmediatamente
   - Si no → Agrega a cola de pendientes
3. **Master publica tarea** → MQTT → Worker específico
4. **Worker recibe tarea**
   - Cambia estado a "busy"
   - Consulta a Gemini API
   - Simula 10 segundos de procesamiento
   - Prepara resultado
5. **Worker envía resultado** → gRPC → Master
6. **Master recibe resultado**
   - Busca sesión del usuario
   - Envía respuesta vía Socket.IO
   - Marca worker como "idle"
7. **Usuario recibe respuesta** en la interfaz web

## 🧪 Verificación del Sistema

### 1. Verificar que todos los servicios estén corriendo

```bash
docker stack services ai-system
```

Todos los servicios deben mostrar REPLICAS en formato X/X (ej: 2/2)

### 2. Verificar logs del Master

```bash
docker service logs ai-system_master | tail -50
```

Buscar mensajes como:
- `[WEB] Servidor web escuchando en puerto 8888`
- `[MQTT] Conectado al broker`
- `[GRPC] Servidor escuchando en puerto 50051`

### 3. Verificar registro de Workers

```bash
docker service logs ai-system_worker-python | grep "registrado"
```

Deberías ver mensajes de registro exitoso.

### 4. Probar una consulta

1. Abre http://10.1.2.166:31663
2. Ingresa tu API Key de Gemini
3. Escribe: "Hola, ¿cómo estás?"
4. Espera ~10 segundos
5. Deberías recibir una respuesta

## 🐛 Troubleshooting

### Problema: Los workers no se registran

**Solución:**
```bash
# Verificar que Mosquitto esté corriendo
docker service ps ai-system_mosquitto

# Reiniciar el stack
./stop.sh
./deploy.sh
```

### Problema: No hay respuesta de la IA

**Causa común:** API Key inválida o límite de tasa excedido

**Solución:**
- Verifica tu API Key en https://aistudio.google.com/api-keys
- Genera una nueva API Key si es necesario
- Verifica logs del worker: `docker service logs ai-system_worker-python | grep "Error"`

### Problema: El Master no recibe callbacks

**Solución:**
```bash
# Verificar que el servidor gRPC esté escuchando
docker service logs ai-system_master | grep "GRPC"

# Verificar conectividad de red
docker network inspect ai-system_ai-network
```

### Problema: Construcción de imagen falla

**Para Go:**
```bash
cd worker-go
go mod tidy
go mod download
```

**Para Java:**
```bash
cd worker-java
mvn clean install
```

## 📊 Escalabilidad

El sistema está diseñado para escalar horizontalmente:

```bash
# Escalar a 10 workers de Python
./scale.sh worker-python 10

# Escalar a 5 workers de Go
./scale.sh worker-go 5

# Escalar a 3 workers de Java
./scale.sh worker-java 3
```

Cada worker:
- Se registra automáticamente
- Recibe su propio tópico MQTT
- Procesa tareas de forma independiente
- Envía resultados directamente al Master

## 🔐 Seguridad

**Recomendaciones:**
- No commitear API Keys en el repositorio
- Usar variables de entorno para configuración sensible
- Implementar autenticación en MQTT en producción
- Usar TLS para comunicaciones gRPC en producción

## 📝 Logs Centralizados

Todos los componentes publican logs en `upb/logs`:

```bash
# Suscribirse a logs en tiempo real
mosquitto_sub -h 10.1.2.166 -p 21662 -t "upb/logs" -v
```

## 🎯 Funcionalidades Implementadas

- ✅ Arquitectura Master-Slave distribuida
- ✅ Comunicación MQTT para distribución de tareas
- ✅ Callbacks gRPC para resultados
- ✅ Web App con Socket.IO para múltiples usuarios
- ✅ Workers en 3 lenguajes diferentes (Python, Go, Java)
- ✅ Integración con Google Gemini API
- ✅ Simulación de procesamiento largo (10s)
- ✅ Sistema de registro y estado de workers
- ✅ Cola de tareas pendientes
- ✅ Logging centralizado en MQTT
- ✅ Docker Swarm para deployment distribuido
- ✅ Registry privado para imágenes
- ✅ Scripts de automatización

## 👥 Autores

**Carlos Daniel Ochoa Molina**
- Node: 10.1.2.166
- Puerto SSH: 11661
- Puerto MQTT: 21662
- Puerto App: 31663

## 📚 Referencias

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [MQTT Protocol](https://mqtt.org/)
- [gRPC Documentation](https://grpc.io/)
- [Socket.IO](https://socket.io/)
- [Google Gemini API](https://ai.google.dev/)

## 📄 Licencia

Este proyecto es parte del Trabajo Final de Sistemas Distribuidos - Universidad Privada Boliviana (UPB)
