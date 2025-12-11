# Guía Rápida de Deployment

## Pasos para Desplegar en el Cluster

### 1. Verificar Conexión al Nodo
```bash
ssh -p 11661 usuario@10.1.2.166
```

### 2. Clonar el Repositorio
```bash
git clone <tu-repositorio>
cd TPFinal_Sistemas_Distribuidos
```

### 3. Inicializar Docker Swarm (si no está activo)
```bash
docker swarm init
```

### 4. Verificar Registry (debe estar corriendo)
```bash
# Si el registry no está corriendo, iniciarlo:
docker run -d -p 5000:5000 --name registry registry:2
```

### 5. Construir y Subir Imágenes
```bash
./build.sh
```

**Tiempo estimado:** 5-10 minutos (primera vez)

### 6. Desplegar el Stack
```bash
./deploy.sh
```

### 7. Verificar Deployment
```bash
# Ver estado de servicios
docker stack services ai-system

# Ver logs del master
docker service logs ai-system_master

# Monitorear en tiempo real
./monitor.sh
```

### 8. Probar la Aplicación

Abre tu navegador:
```
http://10.1.2.166:31663
```

## Comandos Útiles

### Ver Logs
```bash
./logs.sh                          # Menú interactivo
docker service logs -f ai-system_master
docker service logs -f ai-system_worker-python
```

### Escalar Workers
```bash
./scale.sh worker-python 5    # 5 réplicas de Python
./scale.sh worker-go 3        # 3 réplicas de Go
./scale.sh worker-java 2      # 2 réplicas de Java
```

### Detener Todo
```bash
./stop.sh
```

### Reiniciar
```bash
./stop.sh
sleep 10
./deploy.sh
```

## Troubleshooting Rápido

### Servicios no inician
```bash
# Ver por qué falla
docker service ps ai-system_master --no-trunc

# Ver logs completos
docker service logs ai-system_master --tail 100
```

### Workers no se registran
```bash
# Verificar Mosquitto
docker service ps ai-system_mosquitto

# Ver logs de worker
docker service logs ai-system_worker-python
```

### Reconstruir una imagen específica
```bash
cd master
docker build -t 10.1.2.166:5000/master:latest .
docker push 10.1.2.166:5000/master:latest

# Forzar actualización
docker service update --force ai-system_master
```

## Verificación de Componentes

### 1. MQTT Broker
```bash
# Debe estar escuchando en puerto 1883
docker service ls | grep mosquitto
```

### 2. Master
```bash
# Debe tener puerto 31663 (Web) y 50051 (gRPC)
docker service inspect ai-system_master | grep PublishedPort
```

### 3. Workers
```bash
# Verificar cuántos están corriendo
docker service ls | grep worker
```

### 4. Conectividad
```bash
# Verificar red overlay
docker network ls | grep ai-network
docker network inspect ai-system_ai-network
```

## Datos Importantes

- **Nodo:** 10.1.2.166
- **Puerto SSH:** 11661
- **Puerto MQTT:** 21662
- **Puerto Web App:** 31663
- **Registry:** 10.1.2.166:5000
- **Stack Name:** ai-system

## API Keys de Gemini

Obtén tu API Key en: https://aistudio.google.com/api-keys

Puedes usar la API Key de dos formas:
1. Ingresarla en la Web App cada vez
2. Configurarla como variable de entorno en docker-compose.yml

## Logs en Tiempo Real

### MQTT (con mosquitto_sub)
```bash
# Instalar cliente MQTT si no está
sudo apt-get install mosquitto-clients

# Ver todos los logs
mosquitto_sub -h 10.1.2.166 -p 21662 -t "upb/logs" -v

# Ver registros de workers
mosquitto_sub -h 10.1.2.166 -p 21662 -t "upb/workers/register" -v

# Ver estado de workers
mosquitto_sub -h 10.1.2.166 -p 21662 -t "upb/workers/status" -v
```

## Checklist de Verificación

- [ ] Docker Swarm activo: `docker info | grep Swarm`
- [ ] Registry corriendo: `curl http://10.1.2.166:5000/v2/_catalog`
- [ ] Imágenes subidas: Verificar en output de `build.sh`
- [ ] Stack desplegado: `docker stack ls`
- [ ] Servicios corriendo: `docker stack services ai-system`
- [ ] Master accesible: `curl http://10.1.2.166:31663`
- [ ] Workers registrados: Ver logs del master
- [ ] MQTT funcionando: Usar mosquitto_sub

## Flujo Completo de Testing

1. **Abrir Web App:** http://10.1.2.166:31663
2. **Ingresar API Key** de Gemini
3. **Escribir pregunta:** "¿Qué es Docker?"
4. **Observar logs** en otra terminal: `./logs.sh`
5. **Esperar ~10 segundos** (simulación)
6. **Recibir respuesta** en el navegador
7. **Escalar workers:** `./scale.sh worker-python 5`
8. **Hacer múltiples consultas** simultáneas
9. **Verificar balanceo** de carga en los logs

## Estructura de Puertos

| Servicio   | Puerto Interno | Puerto Externo |
|------------|----------------|----------------|
| Web App    | 8888           | 31663          |
| gRPC       | 50051          | 50051          |
| MQTT       | 1883           | 21662          |
| Registry   | 5000           | 5000           |

## Notas Importantes

- El primer build puede tomar varios minutos
- Los workers tardan ~5 segundos en registrarse después del deployment
- Cada consulta simula 10 segundos de procesamiento
- Múltiples usuarios pueden conectarse simultáneamente
- Los workers se auto-asignan IDs únicos al iniciar
