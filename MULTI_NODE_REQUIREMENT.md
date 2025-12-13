# ⚠️ REQUERIMIENTO IMPORTANTE: Multi-VM Deployment

## 📋 Requerimiento del Enunciado

Según el enunciado original del trabajo:

> **"Se deberán desplegar los containers en diferentes VMs utilizando Docker Swarm y un Registry propio, mostrando Workers ejecutándose en diferentes VMs."**

## 🔍 Estado Actual vs Requerido

### ❌ Implementación Actual (Mono-Nodo)

```
┌─────────────────────────────────────────┐
│      Nodo Manager (10.1.2.166)         │
│                                         │
│  ┌─────────────┐                       │
│  │  Master     │ (1 replica)           │
│  └─────────────┘                       │
│                                         │
│  ┌─────────────┐                       │
│  │ Worker-Py   │ (2 replicas)          │
│  └─────────────┘                       │
│                                         │
│  ┌─────────────┐                       │
│  │ Worker-Go   │ (2 replicas)          │
│  └─────────────┘                       │
│                                         │
│  ┌─────────────┐                       │
│  │ Worker-Java │ (2 replicas)          │
│  └─────────────┘                       │
└─────────────────────────────────────────┘

PROBLEMA: Todos los containers en UN solo nodo
```

### ✅ Implementación Requerida (Multi-Nodo)

```
┌──────────────────────┐  ┌──────────────────────┐
│ Manager (10.1.2.166) │  │ Worker1 (10.1.2.167) │
│                      │  │                      │
│  ┌────────────┐      │  │  ┌────────────┐     │
│  │  Master    │      │  │  │ Worker-Py  │     │
│  └────────────┘      │  │  └────────────┘     │
│                      │  │                      │
│  ┌────────────┐      │  │  ┌────────────┐     │
│  │ Mosquitto  │      │  │  │ Worker-Go  │     │
│  └────────────┘      │  │  └────────────┘     │
└──────────────────────┘  └──────────────────────┘
          │
          │
┌──────────────────────┐  ┌──────────────────────┐
│ Worker2 (10.1.2.168) │  │ Worker3 (10.1.2.169) │
│                      │  │                      │
│  ┌────────────┐      │  │  ┌────────────┐     │
│  │ Worker-Py  │      │  │  │ Worker-Java│     │
│  └────────────┘      │  │  └────────────┘     │
│                      │  │                      │
│  ┌────────────┐      │  │  ┌────────────┐     │
│  │ Worker-Go  │      │  │  │ Worker-Java│     │
│  └────────────┘      │  │  └────────────┘     │
└──────────────────────┘  └──────────────────────┘

CORRECTO: Workers distribuidos en diferentes VMs
```

## 🎯 Tu Observación es CORRECTA

Tienes razón al decir:
> "como los 4 tenemos acceso a una parte del cluster, osea como nuestra máquina propia, supongo que talvez cada uno ejecuta un worker"

**¡Exactamente!** El requerimiento implica que:

1. ✅ **Cada miembro del grupo tiene acceso a su nodo**
2. ✅ **Deben unir sus nodos en un Swarm**
3. ✅ **Los workers deben distribuirse entre los nodos**
4. ✅ **Deben demostrar que hay workers en diferentes VMs**

## 🔧 Cómo Configurar Multi-Nodo

### Información del Cluster

Según `cluster_information.txt`:
```
Apellidos: OCHOA MOLINA
Nombres: CARLOS DANIEL
Node: 10.1.2.166
```

**Necesitas obtener:**
- IPs de los otros 3 miembros del grupo
- Acceso SSH a esos nodos
- Permisos para unir al Swarm

### Paso 1: Inicializar Swarm en Manager (Tu nodo)

```bash
# En tu nodo (10.1.2.166)
ssh -p 11661 usuario@10.1.2.166

# Inicializar como manager
docker swarm init --advertise-addr 10.1.2.166

# Output importante - COPIAR este token:
# docker swarm join --token SWMTKN-1-xxx... 10.1.2.166:2377
```

### Paso 2: Unir Otros Nodos al Swarm

```bash
# En nodo del Miembro 2 (ejemplo: 10.1.2.167)
ssh usuario@10.1.2.167

# Unirse al swarm con el token
docker swarm join \
  --token SWMTKN-1-xxx... \
  10.1.2.166:2377
```

```bash
# En nodo del Miembro 3 (ejemplo: 10.1.2.168)
ssh usuario@10.1.2.168

# Unirse al swarm
docker swarm join \
  --token SWMTKN-1-xxx... \
  10.1.2.166:2377
```

```bash
# En nodo del Miembro 4 (ejemplo: 10.1.2.169)
ssh usuario@10.1.2.169

# Unirse al swarm
docker swarm join \
  --token SWMTKN-1-xxx... \
  10.1.2.166:2377
```

### Paso 3: Verificar Nodos

```bash
# Desde el manager (tu nodo)
docker node ls

# Deberías ver algo como:
# ID          HOSTNAME    STATUS  AVAILABILITY  MANAGER STATUS
# abc123 *    node166     Ready   Active        Leader
# def456      node167     Ready   Active        
# ghi789      node168     Ready   Active        
# jkl012      node169     Ready   Active
```

### Paso 4: Modificar docker-compose.yml para Multi-Nodo

```yaml
version: '3.8'

services:
  mosquitto:
    image: eclipse-mosquitto:2.0
    ports:
      - "21662:1883"
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager  # Solo en manager

  master:
    image: 10.1.2.166:5000/master:latest
    ports:
      - "31663:8888"
      - "50051:50051"
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager  # Master en manager

  worker-python:
    image: 10.1.2.166:5000/worker-python:latest
    deploy:
      replicas: 4  # 4 replicas distribuidas
      placement:
        max_replicas_per_node: 1  # Máximo 1 por nodo
        # Se distribuyen automáticamente

  worker-go:
    image: 10.1.2.166:5000/worker-go:latest
    deploy:
      replicas: 4
      placement:
        max_replicas_per_node: 1

  worker-java:
    image: 10.1.2.166:5000/worker-java:latest
    deploy:
      replicas: 4
      placement:
        max_replicas_per_node: 1
```

### Paso 5: Desplegar

```bash
# Desde el manager
./build.sh
./deploy.sh
```

### Paso 6: Verificar Distribución

```bash
# Ver en qué nodo está cada container
docker service ps ai-system_worker-python
docker service ps ai-system_worker-go
docker service ps ai-system_worker-java

# Output mostrará:
# ID    NAME              NODE      DESIRED STATE  CURRENT STATE
# xxx   worker-python.1   node166   Running        Running
# yyy   worker-python.2   node167   Running        Running
# zzz   worker-python.3   node168   Running        Running
# www   worker-python.4   node169   Running        Running
```

## 📸 Evidencia para el Reporte

Para demostrar que funciona en múltiples VMs:

### 1. Captura de Nodos
```bash
docker node ls
```

### 2. Distribución de Workers
```bash
docker service ps --filter "desired-state=running" ai-system_worker-python
docker service ps --filter "desired-state=running" ai-system_worker-go
docker service ps --filter "desired-state=running" ai-system_worker-java
```

### 3. Logs desde Diferentes Nodos
```bash
# Mostrar que cada worker está en nodo diferente
docker service logs ai-system_worker-python | grep "WORKER.*Iniciando"
```

### 4. Captura de Procesamiento Distribuido
```bash
# Hacer consultas y ver qué worker (en qué nodo) las procesa
docker service logs -f ai-system_master | grep "Worker"
```

## ⚠️ Consideraciones Importantes

### Red Overlay
Docker Swarm crea automáticamente una red overlay que permite:
- ✅ Comunicación entre containers en diferentes hosts
- ✅ MQTT funciona entre nodos
- ✅ gRPC callbacks funcionan entre nodos
- ✅ Service discovery automático

### Registry Compartido
Todos los nodos deben poder acceder al registry:
```bash
# En cada nodo worker, verificar acceso
curl http://10.1.2.166:5000/v2/_catalog
```

### Puertos
Solo el manager necesita exponer:
- Puerto 21662 (MQTT)
- Puerto 31663 (Web App)
- Puerto 50051 (gRPC)

Los workers se comunican internamente via la red overlay.

## 🎯 Respuesta a tu Pregunta

### ¿Está mencionado explícitamente?

**Sí, en el enunciado original:**
> "Se deberán desplegar los containers en diferentes VMs utilizando Docker Swarm y un Registry propio, mostrando Workers ejecutándose en diferentes VMs."

### ¿Tu interpretación es correcta?

**¡Absolutamente!** 
- ✅ Cada miembro tiene su nodo
- ✅ Se unen en un Swarm
- ✅ Workers se distribuyen entre nodos
- ✅ Evita sobrecarga en un solo nodo
- ✅ Demuestra escalabilidad real

### ¿Qué hacer?

1. **Coordinar con tu grupo:**
   - Obtener IPs de los otros nodos
   - Decidir quién es el manager
   - Coordinar tokens de join

2. **Configurar el Swarm:**
   - Manager ejecuta `swarm init`
   - Workers ejecutan `swarm join`

3. **Actualizar deployment:**
   - Modificar replicas
   - Agregar constraints de placement
   - Distribuir workers

4. **Documentar en reporte:**
   - Capturas de `docker node ls`
   - Capturas de distribución
   - Logs mostrando diferentes nodos procesando

## 📚 Archivos a Actualizar

- [ ] `docker-compose.yml` - Aumentar replicas y placement
- [ ] `DEPLOYMENT.md` - Agregar sección multi-nodo
- [ ] `README.md` - Documentar setup multi-nodo
- [ ] Crear `MULTI_NODE_SETUP.md` - Guía detallada

¿Quieres que te ayude a configurar el setup multi-nodo?
