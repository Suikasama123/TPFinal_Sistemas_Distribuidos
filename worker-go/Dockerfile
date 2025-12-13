FROM golang:1.23-alpine AS builder

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache git protobuf protobuf-dev

# Copiar go mod files
COPY worker-go/go.mod ./
RUN go mod download

# Instalar plugins de protoc para Go
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28 && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2

# Copiar proto y generar código
COPY proto/worker.proto /proto/
RUN mkdir -p pb && \
    protoc -I/proto --go_out=./pb --go_opt=paths=source_relative \
    --go-grpc_out=./pb --go-grpc_opt=paths=source_relative \
    /proto/worker.proto

# Copiar código fuente
COPY worker-go/ .

# Actualizar dependencias con el código completo
RUN go mod tidy && go mod download

# Compilar
RUN CGO_ENABLED=0 GOOS=linux go build -o worker main.go

# Imagen final
FROM alpine:latest

WORKDIR /app

RUN apk --no-cache add ca-certificates

COPY --from=builder /app/worker .

CMD ["./worker"]
