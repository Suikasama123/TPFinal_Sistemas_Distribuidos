# 📦 Cluster Swarm - Archivos para Deployment

## 📋 CONTENIDO DE ESTA CARPETA

Esta carpeta contiene **TODOS** los archivos necesarios para inicializar y desplegar el sistema distribuido en el cluster.

---

## 📁 ESTRUCTURA DE ARCHIVOS

### 🔧 Scripts de Deployment (Ejecutables)
```
swarm-init.sh       → Inicializar Docker Swarm (EJECUTAR PRIMERO)
build.sh            → Construir imágenes Docker
deploy.sh           → Desplegar el sistema en el cluster
stop.sh             → Detener todos los servicios
```

### 📊 Scripts de Verificación
```
pre-check.sh        → Verificar que todo está listo antes de desplegar
verify.sh           → Verificar estado del sistema
verify-multinode.sh → Verificar distribución multi-nodo
```

### 🔍 Scripts de Monitoreo
```
logs.sh             → Ver logs de servicios
monitor.sh          → Monitorear sistema en tiempo real
scale.sh            → Escalar número de workers
```

### 📂 Directorios de Código
```
master/             → Código del Master (NodeJS)
  ├── src/server.js
  ├── public/index.html
  ├── package.json
  └── Dockerfile

worker-python/      → Worker en Python
  ├── worker.py
  ├── requirements.txt
  └── Dockerfile

worker-go/          → Worker en Go
  ├── main.go
  ├── go.mod
  └── Dockerfile

worker-java/        → Worker en Java
  ├── src/
  ├── pom.xml
  └── Dockerfile

proto/              → Definiciones gRPC
  └── worker.proto

mosquitto/          → Configuración de MQTT
  └── config/mosquitto.conf

config/             → Configuración del sistema
  └── api_keys.json  ← ✅ CON TUS 4 KEYS DE DEEPSEEK
```

### 📄 Archivo de Configuración Principal
```
docker-compose.yml  → Define todos los servicios del cluster
```

---

## 🚀 ORDEN DE EJECUCIÓN

### 1️⃣ INICIALIZAR SWARM (SOLO EN MANAGER)
```bash
cd ~/Desktop/cluster_swarm
./swarm-init.sh
```

**Output:** Te dará un token como:
```
docker swarm join --token SWMTKN-1-xxxxx... 10.1.2.166:2377
```

**Acción:** Copia ese comando y envíaselo a tus 3 compañeros.

---

### 2️⃣ TUS COMPAÑEROS EJECUTAN (EN SUS MÁQUINAS)
```bash
docker swarm join --token SWMTKN-1-xxxxx... 10.1.2.166:2377
```

---

### 3️⃣ VERIFICAR CLUSTER (EN MANAGER)
```bash
docker node ls
```

**Deberías ver 4 nodos con STATUS=Ready**

---

### 4️⃣ BUILD DE IMÁGENES (EN MANAGER)
```bash
./build.sh
```

**Tiempo:** 5-15 minutos la primera vez.

**Qué hace:**
- Construye imagen del Master
- Construye imagen de Worker Python
- Construye imagen de Worker Go
- Construye imagen de Worker Java
- Sube todas las imágenes al registry (10.1.2.166:5000)

---

### 5️⃣ DEPLOY EN CLUSTER (EN MANAGER)
```bash
./deploy.sh
```

**Tiempo:** 1-2 minutos.

**Qué hace:**
- Despliega Master en nodo manager
- Despliega Mosquitto en nodo manager
- Distribuye 12 workers (3 tipos × 4 nodos)
- Configura red overlay automáticamente

---

### 6️⃣ VERIFICAR DEPLOYMENT (EN MANAGER)
```bash
./verify-multinode.sh
```

**Output esperado:**
```
✅ Número de nodos: 4
✅ Workers Python distribuidos en 4 nodos
✅ Workers Go distribuidos en 4 nodos
✅ Workers Java distribuidos en 4 nodos
```

---

### 7️⃣ ACCEDER A LA APLICACIÓN
```
http://10.1.2.166:31793
```

---

## ⚙️ CONFIGURACIÓN INCLUIDA

### ✅ API Keys de DeepSeek (config/api_keys.json)
```json
{
  "keys": [
    { "key": "sk-512624ee943045bdb9bd025191c9105f" },
    { "key": "sk-2253fe52a184456390e8c715c33abf0d" },
    { "key": "sk-a5d8adf586c14b5fa13931e7388a2159" },
    { "key": "sk-04137d3592ec41bf97ffbbfb3e8ab967" }
  ]
}
```

**Las 4 keys ya están configuradas y listas para usar.**

---

## 🔍 VERIFICACIÓN RÁPIDA

Antes de empezar, ejecuta:
```bash
./pre-check.sh
```

Esto verifica:
- ✅ Docker instalado
- ✅ API keys configuradas
- ✅ Archivos presentes
- ✅ Permisos correctos
- ✅ Espacio en disco

---

## 📊 MONITOREO

### Ver estado de servicios:
```bash
docker stack services ai-system
```

### Ver logs en tiempo real:
```bash
./logs.sh
# O específicamente:
docker service logs -f ai-system_master
docker service logs -f ai-system_worker-python
```

### Ver recursos:
```bash
./monitor.sh
```

### Ver distribución por nodo:
```bash
docker service ps ai-system_worker-python
docker service ps ai-system_worker-go
docker service ps ai-system_worker-java
```

---

## 🛠️ COMANDOS ÚTILES

### Escalar workers:
```bash
./scale.sh worker-python 8  # Aumenta a 8 réplicas
```

### Detener todo:
```bash
./stop.sh
```

### Re-desplegar después de cambios:
```bash
./stop.sh
sleep 10
./build.sh    # Solo si cambiaste código
./deploy.sh
```

### Ver logs de un nodo específico:
```bash
# En el nodo worker
docker ps                    # Ver containers locales
docker logs <container-id>   # Ver logs de un container
```

---

## 🎯 ARQUITECTURA DESPLEGADA

```
NODO MANAGER (10.1.2.166) - TÚ:
├── Master (NodeJS) - Puerto 31663
├── Mosquitto (MQTT) - Puerto 21662
├── Worker Python (1 réplica)
├── Worker Go (1 réplica)
└── Worker Java (1 réplica)

NODO WORKER 2 (10.1.2.163):
├── Worker Python (1 réplica)
├── Worker Go (1 réplica)
└── Worker Java (1 réplica)

NODO WORKER 3 (10.1.2.178):
├── Worker Python (1 réplica)
├── Worker Go (1 réplica)
└── Worker Java (1 réplica)

NODO WORKER 4 (10.1.2.173):
├── Worker Python (1 réplica)
├── Worker Go (1 réplica)
└── Worker Java (1 réplica)

TOTAL: 1 Master + 1 MQTT + 12 Workers
```

---

## ⚠️ IMPORTANTE

### Solo TÚ ejecutas en el nodo manager:
- `./swarm-init.sh` ✅
- `./build.sh` ✅
- `./deploy.sh` ✅
- Todos los scripts de verificación y monitoreo ✅

### Tus compañeros solo ejecutan:
- `docker swarm join --token ... IP:2377` ✅
- Nada más (Swarm distribuye todo automáticamente) ✅

---

## 📞 TROUBLESHOOTING

### Si algo falla:
```bash
# Ver logs del master
docker service logs ai-system_master | tail -50

# Ver logs de workers
docker service logs ai-system_worker-python | tail -50

# Reiniciar todo
./stop.sh
sleep 15
./deploy.sh
```

### Si workers no se registran:
```bash
# Verificar conectividad
docker service inspect ai-system_mosquitto
docker service inspect ai-system_master

# Ver estado de la red
docker network inspect ai-system_ai-network
```

---

## ✅ CHECKLIST DE DEPLOYMENT

- [ ] Subir esta carpeta al cluster (10.1.2.166)
- [ ] `cd cluster_swarm`
- [ ] `./pre-check.sh` (verificar)
- [ ] `./swarm-init.sh` (generar token)
- [ ] Compartir token con compañeros
- [ ] Verificar 4 nodos: `docker node ls`
- [ ] `./build.sh` (construir imágenes)
- [ ] `./deploy.sh` (desplegar)
- [ ] `./verify-multinode.sh` (verificar)
- [ ] Acceder: http://10.1.2.166:31793
- [ ] Probar consulta a DeepSeek

---

## 🎉 ¡LISTO!

Esta carpeta contiene **TODO** lo necesario para desplegar el sistema.

**Solo necesitas:**
1. Subirla al cluster
2. Ejecutar los scripts en orden
3. ¡Disfrutar del sistema funcionando!

**Las API keys de DeepSeek ya están configuradas.**
**No necesitas editar nada más.**

---

## 📚 ARCHIVOS DE REFERENCIA

En el directorio original hay más documentación:
- `ARQUITECTURA_DEPLOYMENT.md` - Arquitectura detallada
- `DEEPSEEK_SETUP.md` - Guía de DeepSeek
- `INICIO_RAPIDO.md` - Guía rápida
- `TROUBLESHOOTING.md` - Solución de problemas

---

**¡Proyecto listo para deployment! 🚀**
