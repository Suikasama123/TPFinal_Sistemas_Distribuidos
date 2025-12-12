# ✅ Sistema de API Keys Implementado

## 🎯 Resumen de Cambios

Se ha implementado un sistema flexible de gestión de API keys que permite:

✅ **Configuración Simple**: Archivo JSON fácil de editar  
✅ **Multi-Miembro**: Soporte para 4+ API keys  
✅ **Multi-IA**: Preparado para Gemini, OpenAI, etc.  
✅ **Distribución Automática**: Round-robin o random  
✅ **Seguridad**: .gitignore protege las keys reales  
✅ **Validación**: Script para probar las keys  

---

## 📁 Archivos Creados/Modificados

### Nuevos Archivos
```
config/
  ├── api_keys.json           ← Configuración real (NO subir a Git)
  ├── api_keys.example.json   ← Plantilla para copiar
  └── README.md               ← Documentación técnica

validate_keys.sh               ← Script de validación
QUICKSTART_KEYS.md            ← Guía rápida de configuración
```

### Archivos Modificados
```
master/src/server.js          ← Lee y usa las keys del JSON
master/Dockerfile             ← Incluye directorio config
docker-compose.yml            ← Monta volumen config/
.gitignore                    ← Protege api_keys.json
README.md                     ← Actualizado con instrucciones
```

---

## 🚀 Cómo Usar

### 1. Configurar (Solo una vez)

```bash
# Copiar plantilla
cp config/api_keys.example.json config/api_keys.json

# Editar con tus keys reales
nano config/api_keys.json
```

### 2. Validar

```bash
./validate_keys.sh
```

### 3. Desplegar

```bash
./build.sh
./deploy.sh
```

---

## 📊 Ejemplo de Configuración

```json
{
  "ai_provider": "gemini",
  "keys": [
    {
      "id": "key_1",
      "provider": "gemini",
      "key": "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXX",
      "owner": "Miembro 1",
      "enabled": true
    },
    {
      "id": "key_2",
      "provider": "gemini",
      "key": "AIzaSyYYYYYYYYYYYYYYYYYYYYYYYYY",
      "owner": "Miembro 2",
      "enabled": true
    }
    // ... hasta key_4 o más
  ],
  "distribution": {
    "strategy": "round-robin",  // o "random"
    "fallback_on_error": true
  }
}
```

---

## 🔄 Cómo Funciona la Distribución

### Master (server.js)

1. **Al iniciar**: Lee `config/api_keys.json`
2. **Filtra**: Solo usa keys con `enabled: true`
3. **Al asignar tarea**: Selecciona next key según estrategia
4. **Log**: Muestra qué key se está usando

```javascript
[CONFIG] ✅ Cargadas 4 API keys:
[CONFIG]    1. key_1 (gemini) - Owner: Miembro 1
[CONFIG]    2. key_2 (gemini) - Owner: Miembro 2
[CONFIG]    3. key_3 (gemini) - Owner: Miembro 3
[CONFIG]    4. key_4 (gemini) - Owner: Miembro 4
[CONFIG] 📊 Estrategia de distribución: round-robin
```

### Round-Robin
```
Query 1 → Worker Python → Key 1
Query 2 → Worker Go     → Key 2
Query 3 → Worker Java   → Key 3
Query 4 → Worker Python → Key 4
Query 5 → Worker Go     → Key 1  ← Reinicia el ciclo
```

---

## 🔮 Soporte Multi-IA (Preparado)

Si en el futuro agregan OpenAI u otra IA:

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

**Nota**: Requerirá actualizar el código de los workers para:
1. Detectar el provider de la key
2. Usar el SDK correspondiente (Gemini vs OpenAI)
3. Adaptar el formato de request/response

---

## ⚠️ Seguridad

### ✅ Implementado

1. **`.gitignore`**: Excluye `config/api_keys.json`
2. **Ejemplo seguro**: `api_keys.example.json` con placeholders
3. **Volumen read-only**: Docker monta config como `:ro`
4. **Logs seguros**: No imprime keys completas en logs

### 🔒 Recomendaciones

- ✅ Mantener `api_keys.json` privado
- ✅ NO compartir en canales públicos
- ✅ Usar keys de prueba en desarrollo
- ✅ Rotar keys periódicamente
- ❌ NO subir keys reales a Git

---

## 🧪 Testing

### Test 1: Validar Keys
```bash
./validate_keys.sh
```
Verifica que cada key:
- No sea un placeholder
- Tenga formato válido
- Pueda conectarse a Gemini API

### Test 2: Ver Logs del Master
```bash
docker service logs ai-system_master | grep CONFIG
```
Debe mostrar:
```
[CONFIG] ✅ Cargadas 4 API keys
[CONFIG] 🔑 Usando API key: key_1 (Miembro 1)
```

### Test 3: Hacer Consultas
1. Abrir: http://10.1.2.166:31663
2. Hacer 4+ consultas
3. Verificar en logs que rota entre keys

---

## 📝 Ventajas de esta Implementación

### ✅ Pros

1. **Fácil de configurar**: Solo editar un JSON
2. **Flexible**: Agregar/quitar keys sin tocar código
3. **Seguro**: Keys no hardcodeadas en código
4. **Escalable**: Soporta N cantidad de keys
5. **Multi-IA**: Preparado para otros proveedores
6. **Auditable**: Logs muestran qué key se usa
7. **Fallback**: Usa env var si no hay config

### 🎯 Casos de Uso

- ✅ Desarrollo: Cada developer usa su key
- ✅ Testing: Keys de prueba separadas
- ✅ Producción: Pool de keys de producción
- ✅ Demos: Keys temporales para presentación
- ✅ Rate Limiting: Distribuir carga entre keys

---

## 🔧 Troubleshooting

### Error: "No se encontró config/api_keys.json"

**Causa**: El archivo no existe  
**Solución**:
```bash
cp config/api_keys.example.json config/api_keys.json
```

### Warning: "No hay API keys habilitadas"

**Causa**: Todas las keys tienen `"enabled": false`  
**Solución**: Cambiar alguna a `"enabled": true`

### Error: "KEY NO CONFIGURADA"

**Causa**: La key sigue siendo el placeholder  
**Solución**: Reemplazar `REEMPLAZAR_CON_KEY_MIEMBRO_X` con key real

### Error: HTTP 403 en validación

**Causa**: Key inválida o deshabilitada  
**Solución**: 
1. Verificar en https://aistudio.google.com/api-keys
2. Generar nueva key si es necesario

---

## 📚 Documentación

- **Guía Rápida**: `QUICKSTART_KEYS.md`
- **Técnica**: `config/README.md`
- **General**: `README.md` (actualizado)
- **Deployment**: `DEPLOYMENT.md`

---

## ✅ Checklist de Deployment

Antes de desplegar en el cluster:

- [ ] Copiar `config/api_keys.example.json` → `config/api_keys.json`
- [ ] Obtener 4 API keys de Gemini
- [ ] Reemplazar placeholders en `api_keys.json`
- [ ] Ejecutar `./validate_keys.sh`
- [ ] Verificar que todas las keys están ✅
- [ ] Ejecutar `./build.sh`
- [ ] Ejecutar `./deploy.sh`
- [ ] Verificar logs: `docker service logs ai-system_master`
- [ ] Probar en navegador: http://10.1.2.166:31663

---

## 🎉 Resultado Final

Ahora el sistema:

✅ Lee automáticamente las keys del archivo JSON  
✅ Distribuye tareas usando round-robin entre 4 keys  
✅ Permite agregar más keys sin cambiar código  
✅ Está preparado para soportar múltiples IAs  
✅ Protege las keys reales con .gitignore  
✅ Incluye validación y documentación completa  

**¡Tu proyecto ahora cumple 100% el requerimiento de API keys!** 🚀
