# 🏗️ Arquitectura: API Keys en Docker Swarm

## 📊 Diagrama del Flujo

```
┌─────────────────────────────────────────────────────────┐
│                  DESARROLLO LOCAL                        │
└─────────────────────────────────────────────────────────┘

1. Configurar Keys
   ┌──────────────────┐
   │ config/          │
   │  api_keys.json   │  ← Editar con keys reales
   └──────────────────┘
           │
           ▼
2. Build (./build.sh)
   ┌──────────────────────────────────────┐
   │  Script copia config/ a master/      │
   │  Docker build incluye config/        │
   │  Limpia archivos temporales          │
   └──────────────────────────────────────┘
           │
           ▼
   ┌──────────────────────────────────────┐
   │    Imagen Docker con Keys            │
   │  10.1.2.166:5000/master:latest       │
   │  ┌────────────────────────┐          │
   │  │ /app/config/           │          │
   │  │   api_keys.json ✓      │          │
   │  │   api_keys.example.json│          │
   │  │   README.md            │          │
   │  └────────────────────────┘          │
   └──────────────────────────────────────┘
           │
           ▼
3. Push al Registry
   ┌──────────────────┐
   │  Docker Registry │
   │  10.1.2.166:5000 │
   └──────────────────┘

┌─────────────────────────────────────────────────────────┐
│               DOCKER SWARM CLUSTER                       │
└─────────────────────────────────────────────────────────┘

4. Deploy (./deploy.sh)
   ┌──────────────────────────────────────┐
   │  docker stack deploy -c              │
   │  docker-compose.yml ai-system        │
   └──────────────────────────────────────┘
           │
           ▼
   ┌──────────────────────────────────────┐
   │        Manager Node                   │
   │  10.1.2.166                          │
   │                                       │
   │  ┌─────────────────────────┐         │
   │  │  Master Container       │         │
   │  │  ┌──────────────────┐   │         │
   │  │  │ /app/config/     │   │         │
   │  │  │  api_keys.json ✓ │   │         │
   │  │  └──────────────────┘   │         │
   │  │  Lee keys desde imagen  │         │
   │  └─────────────────────────┘         │
   │                                       │
   │  ┌─────────────────────────┐         │
   │  │  Worker Python          │         │
   │  └─────────────────────────┘         │
   │                                       │
   │  ┌─────────────────────────┐         │
   │  │  Worker Go              │         │
   │  └─────────────────────────┘         │
   │                                       │
   │  ┌─────────────────────────┐         │
   │  │  Worker Java            │         │
   │  └─────────────────────────┘         │
   └──────────────────────────────────────┘

5. Runtime
   ┌──────────────────────────────────────┐
   │  Master lee config/api_keys.json     │
   │  desde /app/config/ (en imagen)      │
   └──────────────────────────────────────┘
           │
           ▼
   ┌──────────────────────────────────────┐
   │  Distribuye keys a Workers           │
   │  Round-robin: key1→key2→key3→key4    │
   └──────────────────────────────────────┘
```

---

## 🔄 Comparación: Volumen vs Imagen

### ❌ Enfoque Incorrecto (Volúmenes)

```yaml
# docker-compose.yml (NO FUNCIONA EN SWARM)
master:
  volumes:
    - ./config:/app/config  ❌
```

**Problema:**
```
Local Machine              Manager Node
┌─────────────┐           ┌─────────────┐
│ ./config/   │     ?     │ ./config/   │  ← NO EXISTE
│  keys.json  │ ─ ─ ─ ─ ─ │  ¿¿¿???     │
└─────────────┘           └─────────────┘
                                │
                          Container no puede
                          leer el archivo
```

### ✅ Enfoque Correcto (En Imagen)

```dockerfile
# Dockerfile
COPY config/ /app/config/  ✅
```

**Solución:**
```
Build Time                Runtime (Swarm)
┌─────────────┐           ┌─────────────────┐
│ ./config/   │           │  Docker Image   │
│  keys.json  │  ──────>  │  ┌───────────┐  │
└─────────────┘           │  │ /app/     │  │
                          │  │  config/  │  │
    COPY durante          │  │   *.json  │  │
    docker build          │  └───────────┘  │
                          └─────────────────┘
                                │
                          Container lee
                          desde imagen
```

---

## 📝 Workflow Detallado

### Primer Deploy

```bash
# Paso 1: Configurar
nano config/api_keys.json
# Reemplazar: REEMPLAZAR_CON_KEY_MIEMBRO_X → AIzaSy...

# Paso 2: Validar (opcional)
bash validate_keys.sh

# Paso 3: Build (incluye keys)
./build.sh
# Script internamente:
#   1. cp -r config/ master/config/
#   2. docker build master/
#   3. rm -rf master/config/

# Paso 4: Deploy
./deploy.sh

# Paso 5: Verificar
docker service logs ai-system_master | grep CONFIG
```

### Actualizar Keys

```bash
# Paso 1: Editar
nano config/api_keys.json
# Cambiar keys o habilitar/deshabilitar

# Paso 2: Rebuild
./build.sh

# Paso 3: Forzar actualización
docker service update --force ai-system_master

# O redesplegar todo
./deploy.sh
```

---

## 🔍 Inspección y Debug

### Ver config en la imagen

```bash
# Listar archivos en la imagen
docker run --rm 10.1.2.166:5000/master:latest ls -la /app/config/

# Ver contenido del archivo
docker run --rm 10.1.2.166:5000/master:latest cat /app/config/api_keys.json
```

### Ver config en container corriendo

```bash
# ID del container
CONTAINER_ID=$(docker ps | grep master | awk '{print $1}')

# Listar archivos
docker exec $CONTAINER_ID ls -la /app/config/

# Ver contenido
docker exec $CONTAINER_ID cat /app/config/api_keys.json
```

### Ver logs de carga

```bash
# Logs del servicio
docker service logs ai-system_master 2>&1 | grep -A 10 CONFIG

# Deberías ver:
# [CONFIG] ✅ Cargadas 4 API keys:
# [CONFIG]    1. key_1 (gemini) - Owner: Miembro 1
# [CONFIG]    2. key_2 (gemini) - Owner: Miembro 2
# ...
```

---

## 🔐 Seguridad en Swarm

### ✅ Ventajas

1. **No expuesto en host**
   - Keys dentro de la imagen
   - No en filesystem del nodo

2. **Registry privado**
   - `10.1.2.166:5000` es local
   - No accesible desde internet

3. **Git ignorado**
   - `api_keys.json` en `.gitignore`
   - Solo `api_keys.example.json` en repo

### ⚠️ Consideraciones

1. **Keys en imagen**
   - Si compartes la imagen, expones las keys
   - Solución: Registry privado + control de acceso

2. **Historial de imagen**
   - Keys quedan en capas de Docker
   - Solución: Usar multi-stage builds (avanzado)

3. **Logs**
   - No imprimir keys completas
   - Solo IDs o primeros caracteres

---

## 💡 Alternativas Avanzadas

### Opción 1: Docker Secrets (Más Seguro)

```bash
# Crear secret
echo "AIzaSy..." | docker secret create gemini_key_1 -

# Usar en compose
services:
  master:
    secrets:
      - gemini_key_1
secrets:
  gemini_key_1:
    external: true
```

### Opción 2: Docker Configs

```bash
# Crear config
docker config create api_keys_v1 config/api_keys.json

# Usar en compose
services:
  master:
    configs:
      - source: api_keys_v1
        target: /app/config/api_keys.json
configs:
  api_keys_v1:
    external: true
```

### Opción 3: Variables de Entorno

```yaml
# docker-compose.yml
master:
  environment:
    - GEMINI_API_KEY_1=${GEMINI_KEY_1}
    - GEMINI_API_KEY_2=${GEMINI_KEY_2}
```

**Comparación:**

| Método | Seguridad | Complejidad | Recomendado |
|--------|-----------|-------------|-------------|
| **En imagen** | ⭐⭐⭐ | ⭐ | ✅ Tu caso |
| Variables env | ⭐⭐ | ⭐⭐ | Para dev |
| Docker Configs | ⭐⭐⭐⭐ | ⭐⭐⭐ | Producción |
| Docker Secrets | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Muy sensible |

---

## 📚 Referencias

- [Docker Build Context](https://docs.docker.com/engine/reference/commandline/build/#extended-description)
- [Docker Swarm Configs](https://docs.docker.com/engine/swarm/configs/)
- [Docker Swarm Secrets](https://docs.docker.com/engine/swarm/secrets/)
- [Best Practices](https://docs.docker.com/develop/dev-best-practices/)
