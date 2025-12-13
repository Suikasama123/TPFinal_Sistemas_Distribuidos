# 🚀 Configuración con DeepSeek (Gratis)

## ✨ ¿Por qué DeepSeek?

- ✅ **Totalmente GRATIS** para uso académico
- ✅ **Sin límite de requests** (más generoso que Gemini)
- ✅ **Registro simple** con email o GitHub
- ✅ **API compatible** con OpenAI (fácil de integrar)

---

## 📝 PASO 1: Obtener API Key de DeepSeek

### 1. Ir al sitio oficial:
👉 **https://platform.deepseek.com/**

### 2. Registrarse:
- Click en "Sign Up"
- Usa tu email o cuenta de GitHub
- Confirma tu email

### 3. Crear API Key:
- Ir a **"API Keys"** en el dashboard
- Click en **"Create API Key"**
- Copiar la key (formato: `sk-...`)

### 4. Repetir para cada miembro:
Cada uno de los 4 miembros debe:
1. Crear su cuenta en DeepSeek
2. Generar su propia API key
3. Compartir su key con el responsable del deployment

---

## 📝 PASO 2: Configurar las Keys

### Opción A - Script Interactivo:
```bash
./configure_keys.sh
```

### Opción B - Manual:
```bash
nano config/api_keys.json
```

Reemplaza cada `REEMPLAZAR_CON_KEY_DEEPSEEK_X` con la key real.

**Formato de DeepSeek:** `sk-xxxxxxxxxxxxxxxxxxxxxxxx`

---

## 📊 Comparación: Gemini vs DeepSeek

| Característica | Gemini | DeepSeek |
|----------------|--------|----------|
| **Costo** | Gratis con límites | Gratis sin límites |
| **Registro** | Cuenta Google | Email/GitHub |
| **Límite Requests** | ~60 req/min | ~300 req/min |
| **Formato Key** | `AIzaSy...` | `sk-...` |
| **Calidad** | Excelente | Muy buena |
| **API URL** | Google Cloud | api.deepseek.com |

---

## 🔧 CONFIGURACIÓN ACTUAL

El archivo `config/api_keys.json` ya está preconfigurado para DeepSeek:

```json
{
  "ai_provider": "multi",
  "keys": [
    {
      "id": "key_1",
      "provider": "deepseek",
      "key": "REEMPLAZAR_CON_KEY_DEEPSEEK_1",
      "owner": "Miembro 1",
      "enabled": true
    },
    // ... 3 más
  ],
  "provider_config": {
    "deepseek": {
      "api_url": "https://api.deepseek.com/v1/chat/completions",
      "model": "deepseek-chat"
    }
  }
}
```

---

## 🧪 PROBAR LA KEY

### Con curl:
```bash
curl https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TU_KEY_AQUI" \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role": "user", "content": "Hola"}]
  }'
```

Si responde con un mensaje, ¡la key funciona! ✅

---

## 📝 EJEMPLO DE KEYS REALES

```json
{
  "keys": [
    {
      "id": "key_1",
      "provider": "deepseek",
      "key": "sk-abc123def456ghi789jkl012mno345pqr",  ← Así se ve una key real
      "owner": "Carlos (10.1.2.179)",
      "enabled": true
    }
  ]
}
```

---

## 🚀 DEPLOYMENT CON DEEPSEEK

Una vez configuradas las keys:

```bash
# 1. Verificar
./pre-check.sh

# 2. Inicializar Swarm
./swarm-init.sh

# 3. Build y Deploy
./build.sh
./deploy.sh

# 4. Probar
# Ir a: http://10.1.2.166:31663
# Hacer una consulta: "¿Qué es un sistema distribuido?"
```

---

## 🔄 CAMBIAR DE DEEPSEEK A GEMINI (Opcional)

Si más adelante quieres usar Gemini:

```bash
nano config/api_keys.json
```

Cambiar:
```json
{
  "provider": "deepseek",       → "provider": "gemini",
  "key": "sk-...",              → "key": "AIzaSy...",
}
```

Y en `ai_provider`:
```json
"ai_provider": "multi"   o   "ai_provider": "gemini"
```

---

## ⚡ VENTAJAS DE DEEPSEEK PARA ESTE PROYECTO

1. **Sin tarjeta de crédito** - Solo email
2. **Límites más altos** - Ideal para pruebas
3. **Misma calidad** - Respuestas comparables a GPT-3.5
4. **API estándar** - Compatible con OpenAI
5. **Perfecto para académico** - Diseñado para estudiantes

---

## 📞 SOPORTE

- **Documentación:** https://platform.deepseek.com/docs
- **Discord:** https://discord.gg/deepseek
- **Email:** support@deepseek.com

---

## ✅ CHECKLIST

- [ ] Cada miembro creó su cuenta en DeepSeek
- [ ] Cada miembro generó su API key (formato `sk-...`)
- [ ] Las 4 keys están en `config/api_keys.json`
- [ ] Se probó al menos una key con curl
- [ ] Ejecutar `./pre-check.sh` para verificar
- [ ] Proceder con `./build.sh` y `./deploy.sh`

**¡DeepSeek es la mejor opción para empezar rápido y gratis! 🎉**
