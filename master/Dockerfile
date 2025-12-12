FROM node:18-alpine

WORKDIR /app

# Instalar wait-for
RUN apk add --no-cache bash curl

# Copiar archivos de package
COPY package*.json ./

# Instalar dependencias
RUN npm install

# Copiar código fuente
COPY . .

# Crear directorio config y copiar archivos de configuración
RUN mkdir -p /app/config

# Copiar archivos de config desde el contexto del build
COPY config/ /app/config/ 2>/dev/null || true

# Si no existe api_keys.json, usar el ejemplo
RUN if [ ! -f /app/config/api_keys.json ]; then \
      cp /app/config/api_keys.example.json /app/config/api_keys.json 2>/dev/null || \
      echo '{"ai_provider":"gemini","keys":[],"distribution":{"strategy":"round-robin"}}' > /app/config/api_keys.json; \
    fi

# Exponer puertos (Web: 8888, gRPC: 50051)
EXPOSE 8888 50051

CMD ["node", "src/server.js"]
