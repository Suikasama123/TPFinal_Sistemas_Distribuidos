# 🐳 Docker Swarm: Configuración de API Keys

## ⚠️ Importante para Docker Swarm

En Docker Swarm, los volúmenes bind locales (`./config:/app/config`) **NO funcionan** en nodos remotos porque el directorio no existe en otros nodos del cluster.

## ✅ Solución Implementada

Las API keys se **incluyen en la imagen Docker** durante el build. Esto significa:

1. El archivo `config/api_keys.json` se copia dentro de la imagen
2. No se necesitan volúmenes bind
3. Funciona en cualquier nodo del Swarm

---

## 🔧 Cómo Configurar

### Paso 1: Editar el archivo de configuración

```bash
# Editar el archivo antes de hacer build
nano config/api_keys.json
```

Reemplazar las keys con las reales:
```json
{
  "keys": [
    {
      "id": "key_1",
      "key": "AIzaSyXXXXXXXXXXXXXXXXXX",  ← Tu key aquí
      "owner": "Miembro 1",
      "enabled": true
    }
    // ... resto de keys
  ]
}
```

### Paso 2: Construir las imágenes

```bash
./build.sh
```

**¿Qué hace el script?**
1. Copia `config/` a `master/config/` temporalmente
2. Construye la imagen del master (incluye el config)
3. Limpia los archivos temporales
4. Sube la imagen al registry

### Paso 3: Desplegar

```bash
./deploy.sh
```

---

## 🔄 ¿Necesitas Cambiar las Keys?

Si necesitas actualizar las API keys después del deployment:

### Opción 1: Rebuild (Recomendado)

```bash
# 1. Editar las keys
nano config/api_keys.json

# 2. Rebuild y redeploy
./build.sh
docker service update --force ai-system_master
```

### Opción 2: Variables de Entorno (Sin rebuild)

Editar `docker-compose.yml`:

```yaml
master:
  environment:
    - GEMINI_API_KEY_1=AIzaSy...
    - GEMINI_API_KEY_2=AIzaSy...
    - GEMINI_API_KEY_3=AIzaSy...
    - GEMINI_API_KEY_4=AIzaSy...
```

Luego actualizar el código en `master/src/server.js` para leer las env vars:

```javascript
// Fallback a variables de entorno
if (enabledKeys.length === 0) {
  const envKeys = [];
  for (let i = 1; i <= 10; i++) {
    const key = process.env[`GEMINI_API_KEY_${i}`];
    if (key) {
      envKeys.push({
        id: `env_key_${i}`,
        provider: 'gemini',
        key: key,
        owner: `Environment Variable ${i}`,
        enabled: true
      });
    }
  }
  enabledKeys = envKeys;
}
```

Redesplegar:
```bash
./deploy.sh
```

---

## 🔒 Seguridad

### ✅ Buenas Prácticas

1. **Nunca subir api_keys.json a Git**
   - Ya está en `.gitignore`
   - Solo sube `api_keys.example.json`

2. **Imagen privada**
   - Tu registry es privado: `10.1.2.166:5000`
   - Las keys están seguras dentro de la imagen

3. **Keys de desarrollo vs producción**
   - Usa keys diferentes para dev y prod
   - Documenta cuál es cuál en el archivo

### ⚠️ Consideraciones

- Las keys quedan "baked" en la imagen Docker
- Si compartes la imagen, compartes las keys
- Para máxima seguridad, usa variables de entorno (Opción 2)

---

## 🧪 Validación

### Antes del Build

```bash
# Validar que las keys están configuradas
cat config/api_keys.json
```

### Después del Deploy

```bash
# Ver logs del master
docker service logs ai-system_master | grep CONFIG

# Deberías ver:
# [CONFIG] ✅ Cargadas 4 API keys
# [CONFIG]    1. key_1 (gemini) - Owner: Miembro 1
```

### Probar en la Web

1. Abrir: `http://10.1.2.166:31663`
2. Hacer una consulta
3. Ver en logs qué key se usó:
   ```
   [CONFIG] 🔑 Usando API key: key_1 (Miembro 1)
   ```

---

## 🐛 Troubleshooting

### Error: "No hay API keys disponibles"

**Causa:** El archivo `api_keys.json` no se copió correctamente

**Solución:**
```bash
# Verificar que existe
ls -la config/api_keys.json

# Verificar contenido
cat config/api_keys.json

# Rebuild
./build.sh
```

### Error: "KEY NO CONFIGURADA"

**Causa:** Las keys siguen siendo placeholders

**Solución:**
```bash
# Editar antes de build
nano config/api_keys.json

# Buscar y reemplazar todos los "REEMPLAZAR_CON_KEY"
```

### Keys no se actualizan

**Causa:** Docker usa imagen en caché

**Solución:**
```bash
# Build sin caché
docker build --no-cache -t 10.1.2.166:5000/master:latest ./master

# O forzar actualización del servicio
docker service update --force ai-system_master
```

---

## 📊 Comparación de Métodos

| Método | Pros | Contras | Swarm-Safe |
|--------|------|---------|------------|
| **Archivo en imagen** | Simple, portable | Requiere rebuild | ✅ Sí |
| **Variables de entorno** | Fácil actualizar | Visible en `docker inspect` | ✅ Sí |
| **Volumen bind** | Actualización en vivo | ❌ No funciona en Swarm | ❌ No |
| **Docker Config** | Nativo de Swarm | Más complejo | ✅ Sí |

**Recomendación:** Usar archivo en imagen (actual implementación)

---

## 🚀 Deployment Completo

```bash
# 1. Configurar keys
nano config/api_keys.json

# 2. Validar (opcional)
bash validate_keys.sh

# 3. Build con keys incluidas
./build.sh

# 4. Deploy en Swarm
./deploy.sh

# 5. Verificar
docker service logs ai-system_master | grep CONFIG
```

---

## 💡 Tips

1. **Backup de keys**: Guarda `api_keys.json` en un lugar seguro
2. **Documentar owners**: Indica quién es dueño de cada key
3. **Rotar keys**: Cambia las keys periódicamente
4. **Monitor de uso**: Revisa los logs para ver distribución de keys
5. **Plan B**: Ten keys de respaldo en caso de que alguna falle

---

## 📚 Referencias

- [Docker Swarm Configs](https://docs.docker.com/engine/swarm/configs/)
- [Docker Swarm Secrets](https://docs.docker.com/engine/swarm/secrets/)
- [Best Practices](https://docs.docker.com/develop/dev-best-practices/)
