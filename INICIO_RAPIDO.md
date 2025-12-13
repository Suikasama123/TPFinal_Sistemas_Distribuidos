# 🚀 Guía Rápida de Deployment - 5 Pasos

## ✅ Todo está listo, solo faltan las API Keys

---

## 📝 PASO 1: Configurar API Keys

Cada miembro del grupo debe obtener su API key de Gemini:
👉 https://aistudio.google.com/api-keys

Luego ejecuta el script de configuración:

```bash
./configure_keys.sh
```

El script te pedirá las 4 keys interactivamente. También puedes editarlas manualmente:

```bash
nano config/api_keys.json
```

Reemplaza cada `REEMPLAZAR_CON_KEY_MIEMBRO_X` con la key real.

---

## 📝 PASO 2: Inicializar Docker Swarm (Nodo Manager)

**Solo TÚ ejecutas esto** en tu máquina (nodo manager):

```bash
./swarm-init.sh
```

Este script te dará un **token** para compartir con los otros 3 miembros.

---

## 📝 PASO 3: Unir Workers al Swarm (Otros 3 Miembros)

**Cada uno de los otros 3 miembros** ejecuta en SU máquina:

```bash
docker swarm join --token SWMTKN-1-xxxxx... 10.1.2.166:2377
```

(Usa el token que generó el PASO 2)

---

## 📝 PASO 4: Verificar que todos están unidos (Manager)

**Tú** verificas que los 4 nodos estén listos:

```bash
docker node ls
```

Deberías ver 4 nodos con STATUS=Ready.

---

## 📝 PASO 5: Build y Deploy (Manager)

**Tú** ejecutas:

```bash
# Verificación pre-deployment (opcional pero recomendado)
./pre-check.sh

# Construir imágenes (5-15 minutos)
./build.sh

# Desplegar en el cluster
./deploy.sh

# Verificar distribución multi-nodo
./verify-multinode.sh
```

---

## 🎯 ¡Listo! Accede a la aplicación

Abre en tu navegador:

```
http://10.1.2.166:31663
```

---

## 🔧 Comandos Útiles

```bash
# Ver estado de servicios
docker stack services ai-system

# Ver logs del master
docker service logs -f ai-system_master

# Ver logs de workers
docker service logs -f ai-system_worker-python

# Escalar workers
./scale.sh worker-python 8

# Ver logs en tiempo real
./logs.sh

# Monitorear sistema
./monitor.sh

# Detener todo
./stop.sh
```

---

## 📊 Información del Cluster

Según `cluster_information.txt`:

- **Miembro 1** (Manager): 10.1.2.179 - Puertos: 11791, 21792, 31793
- **Miembro 2** (Worker):  10.1.2.163 - Puertos: 11631, 21632, 31633
- **Miembro 3** (Worker):  10.1.2.178 - Puertos: 11781, 21782, 31783
- **Miembro 4** (Worker):  10.1.2.173 - Puertos: 11731, 21732, 31753

---

## ❓ Troubleshooting

### Error: "REEMPLAZAR_CON_KEY"
```bash
./configure_keys.sh  # Configura las keys reales
```

### Error: "Swarm not active"
```bash
./swarm-init.sh  # Inicializa Swarm
```

### Workers no se registran
```bash
docker service logs ai-system_master
docker service logs ai-system_worker-python
```

### Reiniciar todo
```bash
./stop.sh
sleep 10
./deploy.sh
```

---

## 📚 Documentación Completa

- `README.md` - Documentación completa del proyecto
- `QUICKSTART_MULTINODE.md` - Guía detallada multi-nodo
- `TROUBLESHOOTING.md` - Solución de problemas
- `TESTING.md` - Ejemplos de pruebas

---

## ✨ Correcciones Aplicadas

✅ Error de `restart_policy` duplicado en docker-compose.yml - CORREGIDO
✅ Error de sintaxis en master/Dockerfile - CORREGIDO
✅ Archivo config/api_keys.json - CREADO
✅ Script de configuración interactiva - CREADO
✅ Script de verificación pre-deployment - CREADO
✅ Permisos de ejecución en scripts - APLICADOS

**El proyecto está 100% listo para deployment.**
