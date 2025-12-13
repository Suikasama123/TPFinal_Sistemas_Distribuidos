FROM node:18-alpine

WORKDIR /app

# Instalar wait-for
RUN apk add --no-cache bash curl

# Copiar archivos de package desde master/
COPY master/package*.json ./

# Instalar dependencias
RUN npm install

# Copiar código fuente del master
COPY master/public ./public

# Copiar archivo proto necesario para gRPC
RUN mkdir -p /proto
COPY proto/worker.proto /proto/

# Crear directorio config ANTES de copiar archivos
RUN mkdir -p /app/config

# Copiar config desde root si existe
COPY config/api_keys.json /app/config/api_keys.json

# Copiar server.js AL FINAL para forzar nuevo layer
RUN mkdir -p /app/src
COPY master/src/server.js /app/src/server.js

# Copiar archivos de config desde el contexto del build (si existen)
# COPY config/ /app/config/

# Si no existe api_keys.json, usar el ejemplo
RUN if [ ! -f /app/config/api_keys.json ]; then \
      cp /app/config/api_keys.example.json /app/config/api_keys.json 2>/dev/null || \
      echo '{"ai_provider":"gemini","keys":[],"distribution":{"strategy":"round-robin"}}' > /app/config/api_keys.json; \
    fi

# Exponer puertos (Web: 8888, gRPC: 50051)
EXPOSE 8888 50051

CMD ["node", "src/server.js"]
