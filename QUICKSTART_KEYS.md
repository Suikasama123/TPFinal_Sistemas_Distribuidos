# 🔑 Guía Rápida: Configuración de API Keys

## ⚠️ IMPORTANTE: Docker Swarm

Este proyecto usa Docker Swarm. Las API keys se **incluyen en la imagen Docker** durante el build.

**Esto significa:**
- ✅ Editar `config/api_keys.json` ANTES de `./build.sh`
- ✅ Funciona en cualquier nodo del Swarm
- ✅ No necesita volúmenes compartidos
- ⚠️ Para cambiar keys, debes rebuild la imagen

📖 **Ver detalles:** `SWARM_API_KEYS.md`

---

## ⚡ Configuración en 3 Pasos

### 1️⃣ Copiar el archivo de configuración

```bash
cp config/api_keys.example.json config/api_keys.json
```

### 2️⃣ Obtener las API Keys de Gemini

Cada miembro del grupo debe:

1. Ir a: **https://aistudio.google.com/api-keys**
2. Iniciar sesión con Google
3. Click en "Create API Key"
4. Copiar la key generada (empieza con `AIzaSy...`)

### 3️⃣ Editar el archivo `config/api_keys.json`

```json
{
  "ai_provider": "gemini",
  "keys": [
    {
      "id": "key_1",
      "provider": "gemini",
      "key": "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXX",  ← Pegar aquí
      "owner": "Miembro 1",
      "enabled": true
    },
    {
      "id": "key_2",
      "provider": "gemini",
      "key": "AIzaSyYYYYYYYYYYYYYYYYYYYYYYYYY",  ← Pegar aquí
      "owner": "Miembro 2",
      "enabled": true
    },
    {
      "id": "key_3",
      "provider": "gemini",
      "key": "AIzaSyZZZZZZZZZZZZZZZZZZZZZZZZZ",  ← Pegar aquí
      "owner": "Miembro 3",
      "enabled": true
    },
    {
      "id": "key_4",
      "provider": "gemini",
      "key": "AIzaSyWWWWWWWWWWWWWWWWWWWWWWWWW",  ← Pegar aquí
      "owner": "Miembro 4",
      "enabled": true
    }
  ],
  "distribution": {
    "strategy": "round-robin",
    "fallback_on_error": true
  }
}
```

---

## ✅ Validar Configuración

```bash
./validate_keys.sh
```

Salida esperada:
```
✅ KEY VÁLIDA Y FUNCIONAL
```

---

## 🔄 Cómo Funciona la Distribución

### Estrategia: Round-Robin (por defecto)

El sistema distribuye las tareas así:

```
Tarea 1 → Key 1 (Miembro 1)
Tarea 2 → Key 2 (Miembro 2)
Tarea 3 → Key 3 (Miembro 3)
Tarea 4 → Key 4 (Miembro 4)
Tarea 5 → Key 1 (Miembro 1)  ← Vuelve al inicio
Tarea 6 → Key 2 (Miembro 2)
...
```

### Estrategia: Random (alternativa)

Para usar distribución aleatoria, cambiar en el archivo:

```json
"distribution": {
  "strategy": "random",  ← Cambiar de "round-robin" a "random"
  "fallback_on_error": true
}
```

---

## 🚫 Deshabilitar una Key

Si una key no funciona o no quieres usarla:

```json
{
  "id": "key_2",
  "provider": "gemini",
  "key": "AIzaSy...",
  "owner": "Miembro 2",
  "enabled": false  ← Cambiar a false
}
```

---

## 🔮 Soporte Multi-IA (Futuro)

Si más adelante usan OpenAI u otra IA:

```json
{
  "ai_provider": "auto",
  "keys": [
    {
      "id": "gemini_1",
      "provider": "gemini",
      "key": "AIzaSy...",
      "enabled": true
    },
    {
      "id": "openai_1",
      "provider": "openai",
      "key": "sk-...",
      "enabled": true
    }
  ]
}
```

Nota: Requerirá actualizar el código de los workers para soportar múltiples proveedores.

---

## ⚠️ Importante: Seguridad

### ✅ Hacer:
- ✅ Mantener `config/api_keys.json` privado
- ✅ NO subir a Git (ya está en `.gitignore`)
- ✅ Compartir keys solo con el equipo
- ✅ Validar keys antes de desplegar

### ❌ NO Hacer:
- ❌ Subir keys reales al repositorio público
- ❌ Compartir keys en canales públicos
- ❌ Usar keys personales en producción sin permiso

---

## 🐛 Troubleshooting

### Problema: "No se encontró config/api_keys.json"

```bash
# Solución: Copiar el ejemplo
cp config/api_keys.example.json config/api_keys.json
```

### Problema: "KEY NO CONFIGURADA"

```bash
# Abre el archivo y reemplaza "REEMPLAZAR_CON_KEY_MIEMBRO_X"
nano config/api_keys.json
```

### Problema: "KEY INVÁLIDA"

- Verifica que copiaste la key completa
- Debe empezar con `AIzaSy...`
- No debe tener espacios al inicio o final

### Problema: "ERROR (HTTP 403)"

- La key puede estar deshabilitada en Google Cloud
- Verifica en https://aistudio.google.com/api-keys
- Genera una nueva key si es necesario

---

## 📊 Verificar que Funciona

### Opción 1: Validar keys
```bash
./validate_keys.sh
```

### Opción 2: Ver logs del Master
```bash
docker service logs ai-system_master
```

Deberías ver:
```
[CONFIG] ✅ Cargadas 4 API keys:
[CONFIG]    1. key_1 (gemini) - Owner: Miembro 1
[CONFIG]    2. key_2 (gemini) - Owner: Miembro 2
[CONFIG]    3. key_3 (gemini) - Owner: Miembro 3
[CONFIG]    4. key_4 (gemini) - Owner: Miembro 4
[CONFIG] 📊 Estrategia de distribución: round-robin
```

### Opción 3: Hacer una consulta
```
1. Abrir: http://10.1.2.166:31663
2. Escribir: "Hola, ¿cómo estás?"
3. Enviar
4. Ver logs: [CONFIG] 🔑 Usando API key: key_1 (Miembro 1)
```

---

## 📚 Más Información

- Ver `config/README.md` para detalles técnicos
- Ver `README.md` para documentación completa
- Ver `DEPLOYMENT.md` para guía de deployment
