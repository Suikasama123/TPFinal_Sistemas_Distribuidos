# Configuración de API Keys

## 📝 Instrucciones

### 1. Obtener API Keys de Gemini

Cada miembro del grupo debe:
1. Ir a https://aistudio.google.com/api-keys
2. Iniciar sesión con cuenta de Google
3. Crear una nueva API key
4. Copiar la key generada

### 2. Configurar el archivo api_keys.json

Editar `config/api_keys.json` y reemplazar las keys:

```json
{
  "id": "key_1",
  "provider": "gemini",
  "key": "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXX",  ← Pegar tu key aquí
  "owner": "Miembro 1",
  "enabled": true
}
```

### 3. Estructura del archivo

```json
{
  "ai_provider": "gemini",           // Proveedor principal (gemini, openai, etc)
  "keys": [                          // Lista de keys
    {
      "id": "key_1",                 // Identificador único
      "provider": "gemini",          // Proveedor de esta key
      "key": "TU_API_KEY_AQUI",      // La key real
      "owner": "Miembro 1",          // Nombre del dueño (opcional)
      "enabled": true                // true = usar, false = ignorar
    }
  ],
  "distribution": {
    "strategy": "round-robin",       // Estrategia de distribución
    "fallback_on_error": true        // Si una key falla, usar otra
  }
}
```

### 4. Estrategias de Distribución

- **round-robin**: Alterna entre keys (key1, key2, key3, key4, key1, ...)
- **random**: Selecciona una key aleatoria
- **least-used**: Usa la key menos utilizada (futuro)

### 5. Soporte Multi-IA (Futuro)

Si más adelante quieren usar otra IA:

```json
{
  "ai_provider": "auto",  // Auto-detectar según la key
  "keys": [
    {
      "id": "key_gemini_1",
      "provider": "gemini",
      "key": "AIzaSy...",
      "enabled": true
    },
    {
      "id": "key_openai_1",
      "provider": "openai",
      "key": "sk-...",
      "enabled": true
    }
  ]
}
```

## 🔒 Seguridad

⚠️ **IMPORTANTE**: 
- NO subir este archivo a Git con keys reales
- Agregar `config/api_keys.json` al `.gitignore`
- Compartir keys solo con miembros del grupo

## 🧪 Validación

Para validar que las keys funcionan:
```bash
./verify.sh
```

Esto probará cada key con una consulta simple a la IA.
