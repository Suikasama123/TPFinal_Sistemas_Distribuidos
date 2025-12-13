# 🎯 Arquitectura de Deployment - Docker Swarm Multi-Nodo

## 📊 DISTRIBUCIÓN DE COMPONENTES

### ✅ CORRECTO: Arquitectura Master-Workers Distribuida

```
┌─────────────────────────────────────────────────────────────┐
│  NODO MANAGER (10.1.2.166) - TÚ                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Servicios en este nodo:                               │ │
│  │  • Master (NodeJS) - Coordina todo el sistema         │ │
│  │  • Mosquitto (MQTT) - Broker de mensajes              │ │
│  │  • Worker Python (1 réplica)                          │ │
│  │  • Worker Go (1 réplica)                              │ │
│  │  • Worker Java (1 réplica)                            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  WORKER NODE 2  │  │  WORKER NODE 3  │  │  WORKER NODE 4  │
│  (10.1.2.163)   │  │  (10.1.2.178)   │  │  (10.1.2.173)   │
│                 │  │                 │  │                 │
│  • Worker-Py    │  │  • Worker-Py    │  │  • Worker-Py    │
│  • Worker-Go    │  │  • Worker-Go    │  │  • Worker-Go    │
│  • Worker-Java  │  │  • Worker-Java  │  │  • Worker-Java  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## 🚀 CÓMO FUNCIONA EL DEPLOYMENT

### 1️⃣ **Inicialización de Swarm (Solo Manager)**

**En TU máquina (10.1.2.166):**
```bash
./swarm-init.sh
```

**Esto:**
- Inicializa Docker Swarm en modo Manager
- Genera un **token de worker**
- Crea archivo `swarm-join-command.txt`

**Output:**
```
✅ Swarm inicializado
Token: SWMTKN-1-xxxxx...
Comando para workers:
docker swarm join --token SWMTKN-1-xxxxx... 10.1.2.166:2377
```

---

### 2️⃣ **Workers se Unen al Swarm**

**Cada uno de tus 3 compañeros ejecuta EN SU MÁQUINA:**

```bash
# Miembro 2 en 10.1.2.163
docker swarm join --token SWMTKN-1-xxxxx... 10.1.2.166:2377

# Miembro 3 en 10.1.2.178
docker swarm join --token SWMTKN-1-xxxxx... 10.1.2.166:2377

# Miembro 4 en 10.1.2.173
docker swarm join --token SWMTKN-1-xxxxx... 10.1.2.166:2377
```

**Resultado:** Cada nodo dice `This node joined a swarm as a worker.`

---

### 3️⃣ **Build y Deploy (Solo Manager)**

**TÚ ejecutas (desde el nodo manager):**

```bash
# Build de imágenes (5-15 minutos)
./build.sh

# Deploy automático en el cluster
./deploy.sh
```

**Docker Swarm automáticamente:**
- ✅ Despliega Master y Mosquitto en el nodo manager
- ✅ Distribuye 12 workers (3 tipos × 4 nodos)
- ✅ Cada nodo recibe 1 worker de cada tipo
- ✅ Configura la red overlay para comunicación

---

## 💡 IMPORTANTE: NO NECESITAS EJECUTAR NADA EN OTRAS MÁQUINAS

### ❌ INCORRECTO:
```bash
# NO hacer esto en cada nodo:
./build.sh    # ❌ Solo en manager
./deploy.sh   # ❌ Solo en manager
```

### ✅ CORRECTO:

| Nodo | Acción Manual | Automático por Swarm |
|------|---------------|----------------------|
| **Manager (tú)** | `./swarm-init.sh`<br>`./build.sh`<br>`./deploy.sh` | Master + Mosquitto + 3 workers |
| **Worker 2** | `docker swarm join ...` | Recibe 3 workers automáticamente |
| **Worker 3** | `docker swarm join ...` | Recibe 3 workers automáticamente |
| **Worker 4** | `docker swarm join ...` | Recibe 3 workers automáticamente |

---

## 🔍 VERIFICACIÓN

### En el Nodo Manager (tú):

```bash
# Ver los 4 nodos del cluster
docker node ls

# Output esperado:
# ID          HOSTNAME    STATUS   AVAILABILITY   MANAGER STATUS
# abc123 *    nodo1       Ready    Active         Leader
# def456      nodo2       Ready    Active        
# ghi789      nodo3       Ready    Active        
# jkl012      nodo4       Ready    Active
```

```bash
# Ver dónde están corriendo los containers
docker service ps ai-system_worker-python

# Output esperado:
# NAME                NODE      DESIRED STATE  CURRENT STATE
# worker-python.1     nodo1     Running        Running
# worker-python.2     nodo2     Running        Running
# worker-python.3     nodo3     Running        Running
# worker-python.4     nodo4     Running        Running
```

### En Nodos Workers (tus compañeros):

```bash
# Solo para verificar que están corriendo containers
docker ps

# Deberían ver 3 containers:
# - worker-python
# - worker-go  
# - worker-java
```

---

## 📝 RESUMEN DEL FLUJO

### Paso 1: Setup Inicial (Una sola vez)
```bash
# EN NODO MANAGER (TÚ):
./swarm-init.sh
# Copiar el token que genera
```

### Paso 2: Unir Nodos (Una sola vez por nodo)
```bash
# EN CADA NODO WORKER (COMPAÑEROS):
docker swarm join --token SWMTKN-1-xxxxx... 10.1.2.166:2377
```

### Paso 3: Verificar Cluster (Manager)
```bash
# EN NODO MANAGER (TÚ):
docker node ls  # Debe mostrar 4 nodos
```

### Paso 4: Build y Deploy (Solo Manager)
```bash
# EN NODO MANAGER (TÚ):
./build.sh      # Construye imágenes
./deploy.sh     # Despliega en todo el cluster
```

### Paso 5: Verificar Deployment (Manager)
```bash
# EN NODO MANAGER (TÚ):
./verify-multinode.sh
docker service ls
docker service ps ai-system_worker-python
```

### Paso 6: Usar la Aplicación
```bash
# Abrir en navegador:
http://10.1.2.166:31663
```

---

## 🎯 PUNTOS CLAVE

1. **Solo el Manager ejecuta build.sh y deploy.sh**
2. **Los workers solo ejecutan `docker swarm join`**
3. **Swarm distribuye automáticamente los containers**
4. **Cada nodo recibe exactamente 1 worker de cada tipo**
5. **La comunicación entre nodos es automática (red overlay)**

---

## 🔧 COMANDOS ÚTILES

### En Nodo Manager:

```bash
# Ver todos los servicios
docker stack services ai-system

# Ver logs del master
docker service logs -f ai-system_master

# Ver logs de workers python
docker service logs -f ai-system_worker-python

# Ver distribución por nodo
./verify-multinode.sh

# Escalar workers (opcional)
docker service scale ai-system_worker-python=8

# Detener todo
./stop.sh
```

### En Nodos Workers:

```bash
# Ver containers locales
docker ps

# Ver logs de un container local
docker logs <container-id>

# Ver recursos
docker stats
```

---

## ✅ ESTADO ACTUAL

- ✅ API Keys de DeepSeek configuradas (4 keys)
- ✅ Código actualizado para soportar DeepSeek
- ✅ docker-compose.yml corregido
- ✅ Dockerfiles corregidos
- ✅ Scripts ejecutables
- ⏳ **Pendiente:** Inicializar Swarm con `./swarm-init.sh`
- ⏳ **Pendiente:** Workers unan al cluster
- ⏳ **Pendiente:** Build y Deploy

**¡Todo listo para comenzar el deployment!** 🚀
