FROM golang:1.21-alpine AS builder

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache git protobuf protobuf-dev

# Copiar go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copiar proto y generar código
COPY ../proto /proto
RUN mkdir -p pb && \
    protoc -I/proto --go_out=./pb --go_opt=paths=source_relative \
    --go-grpc_out=./pb --go-grpc_opt=paths=source_relative \
    /proto/worker.proto

# Copiar código fuente
COPY . .

# Compilar
RUN CGO_ENABLED=0 GOOS=linux go build -o worker main.go

# Imagen final
FROM alpine:latest

WORKDIR /app

RUN apk --no-cache add ca-certificates

COPY --from=builder /app/worker .

CMD ["./worker"]
