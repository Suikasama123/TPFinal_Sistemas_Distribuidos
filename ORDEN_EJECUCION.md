# Orden de Ejecución y Checklist

## 📋 Checklist Pre-Deployment

### Requisitos del Sistema
- [ ] Docker instalado (versión 20.10+)
- [ ] Docker Compose instalado
- [ ] Acceso al nodo del cluster (10.1.2.166)
- [ ] SSH configurado (puerto 11661)
- [ ] API Key de Gemini obtenida
- [ ] Git instalado

### Verificación de Recursos
```bash
# Verificar espacio en disco (mínimo 10GB libre)
df -h

# Verificar memoria (mínimo 4GB)
free -h

# Verificar Docker
docker --version
docker-compose --version

# Verificar conectividad
ping -c 3 10.1.2.166
```

## 🚀 Orden de Ejecución (Primera vez)

### Paso 1: Preparación del Entorno
```bash
# Conectar al nodo
ssh -p 11661 usuario@10.1.2.166

# Navegar al directorio del proyecto
cd /ruta/al/proyecto/TPFinal_Sistemas_Distribuidos

# Verificar archivos
ls -la
```

### Paso 2: Inicializar Docker Swarm
```bash
# Verificar si Swarm ya está activo
docker info | grep "Swarm: active"

# Si no está activo, inicializar
docker swarm init

# Verificar nodo
docker node ls
```

### Paso 3: Configurar Registry (si no existe)
```bash
# Verificar si el registry está corriendo
curl http://10.1.2.166:5000/v2/_catalog

# Si no existe, crear registry
docker run -d \
  -p 5000:5000 \
  --name registry \
  --restart=always \
  -v /var/lib/registry:/var/lib/registry \
  registry:2

# Verificar
curl http://10.1.2.166:5000/v2/_catalog
```

### Paso 4: Construir Imágenes
```bash
# Ejecutar script de build
./build.sh

# Esto tomará 5-15 minutos la primera vez
# Verifica que todas las imágenes se construyan exitosamente
```

**Salida esperada:**
```
[master] Imagen construida exitosamente
[master] Imagen subida exitosamente
[worker-python] Imagen construida exitosamente
[worker-python] Imagen subida exitosamente
[worker-go] Imagen construida exitosamente
[worker-go] Imagen subida exitosamente
[worker-java] Imagen construida exitosamente
[worker-java] Imagen subida exitosamente
```

### Paso 5: Verificar Imágenes en Registry
```bash
# Listar imágenes en registry
curl http://10.1.2.166:5000/v2/_catalog

# Debería mostrar:
# {"repositories":["master","worker-go","worker-java","worker-python"]}
```

### Paso 6: Desplegar Stack
```bash
# Ejecutar script de deployment
./deploy.sh

# Esperar a que los servicios se inicien
sleep 30
```

**Salida esperada:**
```
Desplegando stack 'ai-system'...
Stack desplegado exitosamente

Estado de los servicios:
ID             NAME                       MODE         REPLICAS
xxx            ai-system_master           replicated   1/1
xxx            ai-system_mosquitto        replicated   1/1
xxx            ai-system_worker-python    replicated   2/2
xxx            ai-system_worker-go        replicated   2/2
xxx            ai-system_worker-java      replicated   2/2
```

### Paso 7: Verificar Deployment
```bash
# Ejecutar script de verificación
./verify.sh

# Debería mostrar todos los checks en verde ✓
```

### Paso 8: Verificar Logs
```bash
# Ver logs del Master
docker service logs ai-system_master | tail -20

# Buscar mensajes clave:
# - "[WEB] Servidor web escuchando en puerto 8888"
# - "[MQTT] Conectado al broker"
# - "[GRPC] Servidor escuchando en puerto 50051"
```

### Paso 9: Verificar Registro de Workers
```bash
# Ver logs de workers registrándose
docker service logs ai-system_master | grep "registrado"

# Debería mostrar al menos 6 mensajes de registro (2 de cada tipo)
```

### Paso 10: Probar la Aplicación
```bash
# Verificar que el puerto está abierto
curl http://10.1.2.166:31663

# Abrir en navegador
# http://10.1.2.166:31663
```

## 🧪 Orden de Testing

### Test 1: Consulta Simple
1. Abrir http://10.1.2.166:31663
2. Ingresar tu API Key de Gemini
3. Escribir: "Hola, ¿cómo estás?"
4. Presionar Enter o botón Enviar
5. Esperar ~10 segundos
6. Verificar que recibes una respuesta

**En otra terminal:**
```bash
# Monitorear logs en tiempo real
./logs.sh
# Seleccionar opción 1 (Master)
```

### Test 2: Múltiples Consultas
1. Hacer 5 consultas consecutivas
2. Observar cómo se distribuyen entre workers

```bash
# Ver distribución
docker service logs ai-system_master | grep "Asignando tarea" | tail -5
```

### Test 3: Escalamiento
```bash
# Escalar workers
./scale.sh worker-python 5

# Esperar 10 segundos
sleep 10

# Verificar
docker service ls | grep worker-python

# Hacer 10 consultas rápidas
# Observar mejor distribución
```

### Test 4: Monitoreo
```bash
# Ejecutar monitor
./monitor.sh

# Presionar Ctrl+C para salir
```

## 🔄 Orden de Actualización

### Actualizar Código
```bash
# 1. Modificar código fuente
# 2. Rebuild imagen específica
cd master
docker build -t 10.1.2.166:5000/master:latest .
docker push 10.1.2.166:5000/master:latest

# 3. Actualizar servicio
docker service update --image 10.1.2.166:5000/master:latest ai-system_master

# 4. Verificar
docker service ps ai-system_master
```

### Rolling Update
```bash
# Actualizar con zero-downtime
docker service update \
  --update-parallelism 1 \
  --update-delay 10s \
  --image 10.1.2.166:5000/worker-python:latest \
  ai-system_worker-python
```

## 🛑 Orden de Detención

### Detención Ordenada
```bash
# 1. Detener stack completo
./stop.sh

# 2. Esperar a que todos los contenedores terminen
sleep 15

# 3. Verificar que no hay contenedores
docker ps | grep ai-system

# 4. (Opcional) Limpiar volúmenes
docker volume prune -f

# 5. (Opcional) Limpiar redes
docker network prune -f
```

### Detención de Emergencia
```bash
# Forzar detención inmediata
docker service rm ai-system_master
docker service rm ai-system_mosquitto
docker service rm ai-system_worker-python
docker service rm ai-system_worker-go
docker service rm ai-system_worker-java

# Remover red
docker network rm ai-system_ai-network
```

## 🔧 Orden de Troubleshooting

### Cuando algo falla
```bash
# 1. Verificar estado general
./verify.sh

# 2. Ver servicios que fallan
docker stack ps ai-system --no-trunc

# 3. Ver logs del servicio problemático
docker service logs --tail 50 ai-system_<servicio>

# 4. Ver eventos de Docker
docker events --since 10m

# 5. Inspeccionar servicio
docker service inspect ai-system_<servicio>

# 6. Reiniciar servicio específico
docker service update --force ai-system_<servicio>

# 7. Si persiste, reiniciar todo
./stop.sh
sleep 15
./deploy.sh
```

## 📊 Orden de Monitoreo

### Monitoreo Continuo
```bash
# Terminal 1: Monitor general
./monitor.sh

# Terminal 2: Logs del Master
docker service logs -f ai-system_master

# Terminal 3: Logs MQTT
mosquitto_sub -h 10.1.2.166 -p 21662 -t "upb/logs" -v

# Terminal 4: Stats de recursos
watch -n 2 'docker stats --no-stream'
```

## 📝 Checklist Post-Deployment

### Verificación Completa
- [ ] Todos los servicios en estado "Running"
- [ ] Master accesible en http://10.1.2.166:31663
- [ ] Logs del Master muestran inicio exitoso
- [ ] Al menos 6 workers registrados
- [ ] Mosquitto acepta conexiones
- [ ] Una consulta de prueba funciona
- [ ] Múltiples usuarios pueden conectarse
- [ ] Escalamiento funciona correctamente
- [ ] Logs MQTT muestran actividad
- [ ] No hay errores en logs de servicios

### Documentación
- [ ] README.md leído y entendido
- [ ] DEPLOYMENT.md seguido paso a paso
- [ ] API Key de Gemini configurada
- [ ] Scripts de administración probados
- [ ] Comandos de troubleshooting conocidos

### Seguridad
- [ ] API Keys no comiteadas en git
- [ ] Puertos expuestos correctamente
- [ ] Red overlay funcionando
- [ ] Logs no contienen información sensible

## 🎯 Comandos de Referencia Rápida

```bash
# Estado general
docker stack services ai-system
docker stack ps ai-system

# Logs
./logs.sh
docker service logs -f ai-system_master

# Escalamiento
./scale.sh worker-python 5

# Monitoreo
./monitor.sh
./verify.sh

# Reinicio
./stop.sh && sleep 10 && ./deploy.sh

# Rebuild
./build.sh

# Acceso web
http://10.1.2.166:31663

# MQTT monitoring
mosquitto_sub -h 10.1.2.166 -p 21662 -t "upb/#" -v
```

## ⏱️ Tiempos Estimados

| Actividad                    | Primera Vez | Subsecuente |
|-----------------------------|-------------|-------------|
| Build de imágenes           | 10-15 min   | 3-5 min     |
| Deploy del stack            | 2-3 min     | 1-2 min     |
| Registro de workers         | 30-60 seg   | 30-60 seg   |
| Consulta completa           | 10-15 seg   | 10-15 seg   |
| Escalamiento                | 30-60 seg   | 30-60 seg   |
| Stop del stack              | 30-60 seg   | 30-60 seg   |

## 📞 Soporte

Si encuentras problemas:
1. Consultar TROUBLESHOOTING.md
2. Revisar logs detalladamente
3. Verificar requisitos del sistema
4. Contactar al instructor/TA

---

**Última actualización:** Diciembre 2024
**Versión:** 1.0.0
**Autor:** Carlos Daniel Ochoa Molina
