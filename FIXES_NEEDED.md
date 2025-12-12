# Correcciones Necesarias para Cumplir 100% los Requerimientos

## 1. ⚠️ CRÍTICO: Implementar Pool de API Keys

### Problema
El proyecto actualmente NO implementa el manejo de múltiples API keys como requiere el enunciado:
> "Cada miembro del grupo deberá generar una API key de Gemini que será utilizada por las instancias de los Workers"

### Solución
Modificar `master/src/server.js` para incluir un pool de API keys:

```javascript
// En master/src/server.js, agregar después de las configuraciones:

// Pool de API Keys de Gemini (una por cada miembro del grupo)
const GEMINI_API_KEYS = [
  process.env.GEMINI_API_KEY_1 || 'KEY_MIEMBRO_1',
  process.env.GEMINI_API_KEY_2 || 'KEY_MIEMBRO_2',
  process.env.GEMINI_API_KEY_3 || 'KEY_MIEMBRO_3',
  process.env.GEMINI_API_KEY_4 || 'KEY_MIEMBRO_4',
  process.env.GEMINI_API_KEY_5 || 'KEY_MIEMBRO_5',
  process.env.GEMINI_API_KEY_6 || 'KEY_MIEMBRO_6',
];

let currentKeyIndex = 0;

// Función para obtener la siguiente API key (round-robin)
function getNextApiKey() {
  const key = GEMINI_API_KEYS[currentKeyIndex % GEMINI_API_KEYS.length];
  currentKeyIndex++;
  return key;
}

// Modificar la función assignTaskToWorker:
function assignTaskToWorker(workerId, task) {
  workers.get(workerId).status = 'busy';
  
  // Usar API key del pool si el usuario no proporcionó una
  const apiKey = task.apiKey || getNextApiKey();
  
  const taskMessage = {
    worker_id: workerId,
    session_id: task.sessionId,
    query: task.query,
    api_key: apiKey,  // <-- Usar del pool
    grpc_endpoint: `${MASTER_HOST}:${GRPC_PORT}`,
    timestamp: task.timestamp
  };
  
  // ... resto del código
}
```

### Actualizar docker-compose.yml:
```yaml
master:
  environment:
    - GEMINI_API_KEY_1=<tu_key_1>
    - GEMINI_API_KEY_2=<tu_key_2>
    - GEMINI_API_KEY_3=<tu_key_3>
    # Agregar tantas como miembros tenga el grupo
```

---

## 2. ⚠️ IMPORTANTE: Implementar Wait-for Robusto

### Problema
El enunciado dice:
> "Los Workers deberán 'registrarse' y el sistema deberá asegurarse de que el broker MQTT está listo para recibir mensajes, antes que los registros de los Workers (usar wait-for)."

Actualmente solo hay `sleep(5)` que no es robusto.

### Solución Opción 1: Healthcheck en Docker Compose

Modificar `docker-compose.yml`:

```yaml
services:
  mosquitto:
    image: eclipse-mosquitto:2.0
    healthcheck:
      test: ["CMD", "mosquitto_sub", "-t", "$$SYS/broker/uptime", "-C", "1", "-i", "healthcheck", "-W", "3"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
    # ... resto de configuración

  master:
    depends_on:
      mosquitto:
        condition: service_healthy  # ← Esperar a healthcheck
    # ... resto

  worker-python:
    depends_on:
      mosquitto:
        condition: service_healthy
      master:
        condition: service_started
    # ... resto

  worker-go:
    depends_on:
      mosquitto:
        condition: service_healthy
      master:
        condition: service_started
    # ... resto

  worker-java:
    depends_on:
      mosquitto:
        condition: service_healthy
      master:
        condition: service_started
    # ... resto
```

### Solución Opción 2: Script wait-for-it

1. Descargar `wait-for-it.sh`:
```bash
wget https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
chmod +x wait-for-it.sh
```

2. Copiar a cada worker y modificar Dockerfiles:

**worker-python/Dockerfile:**
```dockerfile
COPY wait-for-it.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wait-for-it.sh

CMD ["wait-for-it.sh", "mosquitto:1883", "--timeout=60", "--", "python", "worker.py"]
```

**worker-go/Dockerfile:**
```dockerfile
COPY wait-for-it.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wait-for-it.sh

CMD ["wait-for-it.sh", "mosquitto:1883", "--timeout=60", "--", "./worker-go"]
```

**worker-java/Dockerfile:**
```dockerfile
COPY wait-for-it.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wait-for-it.sh

CMD ["wait-for-it.sh", "mosquitto:1883", "--timeout=60", "--", "java", "-jar", "worker.jar"]
```

---

## 3. 🔧 MENOR: Corregir import duplicado en Go

En `worker-go/main.go` línea 8-9:
```go
import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os"  // ← DUPLICADO, eliminar esta línea
	"time"
	// ...
)
```

---

## 4. 📊 OPCIONAL: Agregar visualización de logs en Web UI

Agregar a `master/public/index.html` una sección para ver logs en tiempo real:

```html
<!-- Agregar antes del input-area -->
<div class="logs-section">
  <h3>Logs del Sistema</h3>
  <div id="logs-container"></div>
</div>
```

```javascript
// En el script, suscribirse a logs:
socket.on('system-log', (log) => {
  addLog(log);
});

function addLog(log) {
  const logsContainer = document.getElementById('logs-container');
  const logDiv = document.createElement('div');
  logDiv.className = 'log-entry';
  logDiv.textContent = `[${log.source}] ${log.message}`;
  logsContainer.appendChild(logDiv);
  // Limitar a últimos 50 logs
  if (logsContainer.children.length > 50) {
    logsContainer.removeChild(logsContainer.firstChild);
  }
}
```

En `master/src/server.js`:
```javascript
mqttClient.on('message', (topic, message) => {
  const data = JSON.parse(message.toString());
  
  if (topic === 'upb/logs') {
    console.log(`[LOG] ${data.message}`);
    // Broadcast a todos los clientes web
    io.emit('system-log', data);
  }
  // ... resto
});
```

---

## 5. 📝 DOCUMENTACIÓN: Actualizar README con API Keys

Agregar sección en README.md:

```markdown
## 🔑 Configuración de API Keys de Gemini

Cada miembro del grupo debe:

1. Obtener una API key de Gemini: https://aistudio.google.com/api-keys
2. Agregar su key al archivo `.env` o directamente en `docker-compose.yml`

### Opción 1: Variables de entorno

Crear archivo `.env`:
```
GEMINI_API_KEY_1=tu_key_aqui
GEMINI_API_KEY_2=key_miembro_2
GEMINI_API_KEY_3=key_miembro_3
```

### Opción 2: Directamente en docker-compose.yml

```yaml
master:
  environment:
    - GEMINI_API_KEY_1=AIzaSy...
    - GEMINI_API_KEY_2=AIzaSy...
```

El sistema distribuirá automáticamente las keys entre los workers usando round-robin.
```

---

## Checklist de Implementación

- [ ] Implementar pool de API keys en master
- [ ] Agregar healthcheck a mosquitto
- [ ] Actualizar depends_on con condition: service_healthy
- [ ] Corregir import duplicado en Go
- [ ] (Opcional) Agregar logs en Web UI
- [ ] Actualizar README con instrucciones de API keys
- [ ] Probar con múltiples usuarios simultáneos
- [ ] Verificar escalamiento de workers
- [ ] Documentar la distribución de API keys

---

## Prioridad de Implementación

1. **URGENTE** - Pool de API Keys (requerimiento explícito)
2. **ALTA** - Wait-for con healthcheck (requerimiento explícito)
3. **MEDIA** - Corregir import duplicado
4. **BAJA** - Mejoras opcionales (logs UI, documentación adicional)
