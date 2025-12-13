# Pruebas y Ejemplos de Uso

## Ejemplos de Consultas para Probar

### Consultas Simples
1. "Hola, ¿cómo estás?"
2. "¿Qué es Docker Swarm?"
3. "Explica qué es gRPC"
4. "¿Para qué sirve MQTT?"

### Consultas Técnicas
1. "Explica la diferencia entre REST y gRPC"
2. "¿Cuáles son las ventajas de una arquitectura Master-Slave?"
3. "¿Qué es un sistema distribuido?"
4. "Explica cómo funciona Docker Swarm"

### Consultas de Código
1. "Genera un ejemplo de un servidor HTTP en Python"
2. "¿Cómo se conecta a MQTT con Go?"
3. "Ejemplo de cliente gRPC en Java"
4. "Código de Socket.IO en Node.js"

### Consultas Complejas (para probar el sistema)
1. "Explica detalladamente cómo funciona el protocolo MQTT, sus niveles de QoS, y casos de uso en IoT"
2. "Describe la arquitectura de microservicios, sus ventajas y desventajas comparado con monolitos"
3. "¿Cuáles son las diferencias entre Docker Compose y Docker Swarm? Proporciona ejemplos"

## Escenarios de Prueba

### Escenario 1: Una Consulta Simple
**Objetivo:** Verificar funcionamiento básico

1. Abrir http://10.1.2.166:31663
2. Ingresar API Key
3. Escribir: "Hola, ¿cómo estás?"
4. Enviar
5. Esperar ~10 segundos
6. Verificar respuesta

**Verificación:**
```bash
# En otra terminal
docker service logs -f ai-system_master
```

Deberías ver:
- `[QUERY] Sesión XXX: Hola, ¿cómo estás?`
- `[TASK] Asignando tarea a worker XXX`
- `[GRPC] Resultado recibido del worker XXX`

### Escenario 2: Múltiples Consultas Secuenciales
**Objetivo:** Verificar que el sistema maneja múltiples consultas del mismo usuario

1. Hacer 5 consultas seguidas
2. Observar cómo se asignan a diferentes workers

**Comandos:**
```bash
./logs.sh  # Seleccionar opción 6 (Todos)
```

### Escenario 3: Múltiples Usuarios Simultáneos
**Objetivo:** Probar concurrencia

1. Abrir 3-5 pestañas del navegador
2. Cada una en http://10.1.2.166:31663
3. Hacer consultas desde todas al mismo tiempo
4. Verificar que todas reciben respuestas

**Verificación:**
```bash
docker service logs ai-system_master | grep "Nueva sesión"
```

### Escenario 4: Saturación del Sistema
**Objetivo:** Probar el sistema de cola

1. Escalar workers a 1 de cada tipo:
```bash
./scale.sh worker-python 1
./scale.sh worker-go 1
./scale.sh worker-java 1
```

2. Hacer 10 consultas rápidamente
3. Observar mensajes de "Tarea en cola"
4. Escalar workers:
```bash
./scale.sh worker-python 5
```
5. Ver cómo se procesan las tareas pendientes

### Escenario 5: Verificar Load Balancing
**Objetivo:** Confirmar distribución de carga

1. Escalar a múltiples workers:
```bash
./scale.sh worker-python 3
./scale.sh worker-go 3
./scale.sh worker-java 3
```

2. Hacer 20 consultas
3. Verificar que se distribuyen entre workers:
```bash
docker service logs ai-system_master | grep "Asignando tarea" | tail -20
```

### Escenario 6: Failover de Worker
**Objetivo:** Probar recuperación ante fallos

1. Iniciar consulta
2. Durante el procesamiento, eliminar el worker:
```bash
# Obtener ID del contenedor
docker ps | grep worker-python

# Eliminar el contenedor
docker rm -f <container_id>
```

3. Observar que Swarm reinicia automáticamente el worker
4. El nuevo worker se registra y procesa nuevas tareas

### Escenario 7: Monitoreo de Logs MQTT
**Objetivo:** Ver comunicación MQTT en tiempo real

1. Instalar cliente MQTT:
```bash
sudo apt-get install mosquitto-clients
```

2. Suscribirse a logs:
```bash
mosquitto_sub -h 10.1.2.166 -p 21662 -t "upb/logs" -v
```

3. En otra terminal, hacer consultas
4. Observar todos los logs en tiempo real

### Escenario 8: Escalamiento Dinámico
**Objetivo:** Probar escalabilidad horizontal

1. Estado inicial:
```bash
docker stack services ai-system
```

2. Escalar progresivamente:
```bash
./scale.sh worker-python 2
sleep 10
./scale.sh worker-python 5
sleep 10
./scale.sh worker-python 10
```

3. Hacer consultas durante el escalamiento
4. Observar que los nuevos workers se registran automáticamente

## Métricas a Observar

### Tiempo de Respuesta
- **Esperado:** ~10 segundos (simulación)
- **Real con Gemini:** Variable según carga de la API

### Registro de Workers
- **Esperado:** 3-5 segundos después del inicio
- **Indica éxito:** Mensaje "Worker XXX registrado" en logs

### Asignación de Tareas
- **Balanceo:** Tareas distribuidas equitativamente
- **Cola:** Mensajes "Tarea en cola" cuando todos busy

### Callbacks gRPC
- **Latencia:** < 1 segundo
- **Success:** Mensaje "Resultado recibido correctamente"

## Pruebas Automatizadas

### Script de Carga (Bash)
```bash
#!/bin/bash
# test_load.sh

for i in {1..20}; do
    echo "Consulta $i"
    curl -X POST http://10.1.2.166:31663 \
         -H "Content-Type: application/json" \
         -d "{\"query\": \"Test $i\", \"apiKey\": \"YOUR_KEY\"}"
    sleep 1
done
```

### Monitor de Estado
```bash
#!/bin/bash
# monitor_workers.sh

while true; do
    echo "=== $(date) ==="
    docker service ls | grep worker
    echo ""
    sleep 5
done
```

## Comandos de Verificación

### Ver qué workers están procesando
```bash
docker service logs ai-system_worker-python | grep "procesando tarea"
```

### Contar tareas completadas
```bash
docker service logs ai-system_master | grep "Resultado recibido" | wc -l
```

### Ver distribución de workers por nodo
```bash
docker service ps ai-system_worker-python --format "{{.Node}}\t{{.CurrentState}}"
```

### Verificar uso de recursos
```bash
docker stats --no-stream
```

## Troubleshooting de Pruebas

### Si no hay respuesta:
1. Verificar que el worker recibió la tarea:
```bash
docker service logs ai-system_worker-python | tail -20
```

2. Verificar API Key:
```bash
docker service logs ai-system_worker-python | grep "Error"
```

3. Verificar callback gRPC:
```bash
docker service logs ai-system_master | grep "GRPC"
```

### Si los workers no se registran:
1. Verificar Mosquitto:
```bash
docker service logs ai-system_mosquitto
```

2. Verificar conectividad de red:
```bash
docker network inspect ai-system_ai-network
```

### Si hay muchas tareas en cola:
1. Escalar workers:
```bash
./scale.sh worker-python 10
./scale.sh worker-go 10
```

## Checklist de Pruebas

- [ ] Consulta simple funciona
- [ ] Múltiples consultas secuenciales funcionan
- [ ] Múltiples usuarios simultáneos funcionan
- [ ] Sistema de cola funciona (saturación)
- [ ] Load balancing distribuye tareas
- [ ] Workers se recuperan de fallos (Swarm reinicia)
- [ ] Logs MQTT muestran todas las operaciones
- [ ] Escalamiento dinámico funciona
- [ ] Callbacks gRPC funcionan correctamente
- [ ] Web App responde correctamente

## Resultados Esperados

### Por Consulta
- ✅ Worker asignado en < 1 segundo
- ✅ Gemini responde en 1-5 segundos
- ✅ Simulación de 10 segundos
- ✅ Callback gRPC en < 1 segundo
- ✅ Respuesta al usuario en ~10-15 segundos total

### Por Worker
- ✅ Registro exitoso en 3-5 segundos
- ✅ Estado cambia: idle → busy → idle
- ✅ Logs en MQTT visibles
- ✅ Auto-recuperación ante fallos

### Por Sistema
- ✅ Múltiples usuarios soportados
- ✅ Cola de tareas funcional
- ✅ Balanceo de carga efectivo
- ✅ Escalamiento sin downtime
- ✅ Logs centralizados funcionando
