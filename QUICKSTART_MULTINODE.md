# Guía Rápida: Setup Multi-Nodo

## 🎯 Objetivo
Configurar el sistema en 4 VMs diferentes (una por cada miembro del grupo) cumpliendo con el requerimiento del enunciado.

## 👥 Roles del Grupo

| Rol | Miembro | IP Ejemplo | Responsabilidad |
|-----|---------|------------|-----------------|
| **Manager** | Tú | 10.1.2.166 | Inicializa Swarm, Registry, Deploy |
| **Worker 1** | Miembro 2 | 10.1.2.??? | Join al Swarm |
| **Worker 2** | Miembro 3 | 10.1.2.??? | Join al Swarm |
| **Worker 3** | Miembro 4 | 10.1.2.??? | Join al Swarm |

## ⚡ Setup Rápido (15 minutos)

### 1️⃣ Manager (TÚ) - Inicializar Swarm

```bash
# En tu nodo (10.1.2.166)
cd TPFinal_Sistemas_Distribuidos

# Ejecutar script de inicialización
chmod +x swarm-init.sh
./swarm-init.sh
```

**Output esperado:**
```
✅ Swarm inicializado exitosamente
Token de Worker: SWMTKN-1-xxxxx...
```

El script genera un archivo `swarm-join-command.txt` con el comando.

---

### 2️⃣ Workers (Miembros 2, 3, 4) - Unirse al Swarm

**Compartir con los otros 3 miembros:**
- El archivo `swarm-join-command.txt` O
- El comando que salió en pantalla

**Cada miembro debe ejecutar en SU nodo:**

```bash
# Miembro 2 en su nodo
ssh usuario@10.1.2.XXX  # Su IP

# Ejecutar el comando de join
docker swarm join \
  --token SWMTKN-1-xxxxx... \
  10.1.2.166:2377
```

Repetir para Miembro 3 y Miembro 4 en sus respectivos nodos.

---

### 3️⃣ Manager (TÚ) - Verificar Nodos

```bash
# Ver que los 4 nodos estén unidos
docker node ls
```

**Deberías ver:**
```
ID          HOSTNAME    STATUS  AVAILABILITY  MANAGER STATUS
abc123 *    tu-nodo     Ready   Active        Leader
def456      nodo-m2     Ready   Active        
ghi789      nodo-m3     Ready   Active        
jkl012      nodo-m4     Ready   Active
```

✅ **4 nodos = Ready**

---

### 4️⃣ Manager (TÚ) - Configurar API Keys

```bash
# Editar archivo de configuración
nano config/api_keys.json
```

Agregar las 4 API keys (una por miembro).

---

### 5️⃣ Manager (TÚ) - Build y Deploy

```bash
# Build de imágenes (incluye API keys)
./build.sh

# Deploy en el Swarm multi-nodo
./deploy.sh
```

---

### 6️⃣ Verificar Distribución Multi-Nodo

```bash
# Script de verificación
chmod +x verify-multinode.sh
./verify-multinode.sh
```

**Deberías ver:**
```
✅ Número de nodos: 4 (cumple: >= 4)
✅ Workers Python distribuidos en 4 nodos
✅ Workers Go distribuidos en 4 nodos
✅ Workers Java distribuidos en 4 nodos

✅ SISTEMA MULTI-NODO VERIFICADO
```

---

## 📊 Verificación Visual

### Ver distribución de containers:

```bash
# Workers Python en diferentes nodos
docker service ps ai-system_worker-python

# Output esperado:
NAME                NODE      DESIRED STATE  CURRENT STATE
worker-python.1     tu-nodo   Running        Running
worker-python.2     nodo-m2   Running        Running
worker-python.3     nodo-m3   Running        Running
worker-python.4     nodo-m4   Running        Running
```

---

## 🧪 Probar el Sistema

### 1. Abrir la Web App

```
http://10.1.2.166:31663
```

### 2. Hacer Consultas

Escribe varias consultas y observa en los logs qué worker (en qué nodo) las procesa.

### 3. Ver Logs Distribuidos

```bash
# Ver logs del master
docker service logs -f ai-system_master

# Deberías ver logs de workers en diferentes nodos procesando
[TASK] Asignando tarea a worker python-worker-nodo-m2-xxx
[TASK] Asignando tarea a worker go-worker-nodo-m3-xxx
[TASK] Asignando tarea a worker java-worker-nodo-m4-xxx
```

---

## 📸 Evidencia para el Reporte

### Captura 1: Nodos del Swarm
```bash
docker node ls
```
**Debe mostrar 4 nodos**

### Captura 2: Distribución de Workers
```bash
docker service ps ai-system_worker-python
docker service ps ai-system_worker-go
docker service ps ai-system_worker-java
```
**Debe mostrar containers en diferentes NODEs**

### Captura 3: Logs Mostrando Distribución
```bash
./verify-multinode.sh
```
**Debe mostrar resumen con checkmarks ✅**

### Captura 4: Web App Funcionando
- Screenshot de la interfaz web
- Mostrando respuestas de diferentes workers

---

## ⚠️ Troubleshooting

### Problema: "No se puede unir al Swarm"

**Causa:** Firewall bloqueando puertos

**Solución:**
```bash
# En todos los nodos, abrir puertos
sudo firewall-cmd --add-port=2377/tcp --permanent  # Swarm management
sudo firewall-cmd --add-port=7946/tcp --permanent  # Swarm networking
sudo firewall-cmd --add-port=7946/udp --permanent
sudo firewall-cmd --add-port=4789/udp --permanent  # Overlay network
sudo firewall-cmd --reload
```

### Problema: "No puede bajar la imagen del registry"

**Causa:** Workers no tienen acceso al registry

**Solución:**
```bash
# En cada nodo worker, verificar acceso
curl http://10.1.2.166:5000/v2/_catalog

# Si falla, verificar que el registry esté corriendo en el manager
docker service ls | grep registry
```

### Problema: "Todos los workers en un solo nodo"

**Causa:** No hay suficientes nodos o constraints incorrectos

**Solución:**
```bash
# Verificar nodos disponibles
docker node ls

# Si hay 4 nodos pero no se distribuyen, verificar docker-compose.yml
# Debe tener: max_replicas_per_node: 1
```

---

## 🎯 Checklist de Completitud

- [ ] 4 nodos unidos al Swarm
- [ ] `docker node ls` muestra 4 nodos Ready
- [ ] Master corriendo en Manager
- [ ] 4 workers Python (1 por nodo)
- [ ] 4 workers Go (1 por nodo)
- [ ] 4 workers Java (1 por nodo)
- [ ] `verify-multinode.sh` muestra ✅
- [ ] Web App accesible y funcional
- [ ] Capturas de pantalla tomadas
- [ ] Logs muestran distribución

---

## 🚀 Comandos de Referencia Rápida

```bash
# Inicializar (Manager)
./swarm-init.sh

# Unir (Workers)
docker swarm join --token TOKEN IP:2377

# Verificar nodos
docker node ls

# Build y Deploy
./build.sh && ./deploy.sh

# Verificar distribución
./verify-multinode.sh

# Ver estado
docker stack ps ai-system

# Ver logs
docker service logs -f ai-system_master
```

---

## 📚 Documentación Completa

- `MULTI_NODE_REQUIREMENT.md` - Explicación detallada del requerimiento
- `ARCHITECTURE_SWARM.md` - Arquitectura y diagramas
- `DEPLOYMENT.md` - Guía completa de deployment

---

¡Con esto cumples 100% el requerimiento de "Workers ejecutándose en diferentes VMs"! 🎉
