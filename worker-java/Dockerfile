FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /app

# Copiar proto
COPY proto/worker.proto /proto/

# Copiar pom
COPY worker-java/pom.xml .

# Descargar dependencias
RUN mvn dependency:go-offline

# Copiar código fuente
COPY worker-java/src ./src

# Compilar
RUN mvn clean package -DskipTests

# Imagen final
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

COPY --from=builder /app/target/worker-java-1.0.0.jar worker.jar

CMD ["java", "-jar", "worker.jar"]
