FROM python:3.11-slim

WORKDIR /app

# Copiar requirements
COPY requirements.txt .

# Instalar dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente y proto
COPY . .

# Generar código gRPC desde proto
RUN python -m grpc_tools.protoc -I../proto --python_out=. --grpc_out=. ../proto/worker.proto

CMD ["python", "worker.py"]
