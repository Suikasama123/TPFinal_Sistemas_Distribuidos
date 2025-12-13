FROM python:3.11-slim

WORKDIR /app

# Copiar requirements
COPY requirements.txt .

# Instalar dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copiar proto primero
COPY proto/worker.proto /proto/

# Generar código gRPC desde proto
RUN python -m grpc_tools.protoc -I/proto --python_out=. --grpc_out=. /proto/worker.proto

# Copiar código fuente
COPY worker-python/ .

CMD ["python", "worker.py"]
