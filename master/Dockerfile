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

# Crear directorio config si no existe (para montar volumen)
RUN mkdir -p /app/config

# Exponer puertos (Web: 8888, gRPC: 50051)
EXPOSE 8888 50051

CMD ["node", "src/server.js"]
