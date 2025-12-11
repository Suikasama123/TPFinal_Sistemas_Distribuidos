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

# Exponer puertos (Web: 8888, gRPC: 50051)
EXPOSE 8888 50051

CMD ["node", "src/server.js"]
