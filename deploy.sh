#!/bin/bash

# Script para desplegar el stack en Docker Swarm
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

STACK_NAME="ai-system"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Desplegando stack en Docker Swarm${NC}"
echo -e "${GREEN}========================================${NC}"

# Verificar que estamos en un nodo de swarm
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${RED}Error: Docker Swarm no está activo en este nodo${NC}"
    echo -e "${YELLOW}Inicializa Swarm con: docker swarm init${NC}"
    exit 1
fi

# Crear directorios necesarios para mosquitto si no existen
mkdir -p mosquitto/data mosquitto/log
chmod -R 777 mosquitto

# Desplegar el stack
echo -e "\n${YELLOW}Desplegando stack '${STACK_NAME}'...${NC}"
docker stack deploy -c docker-compose.yml ${STACK_NAME}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Stack desplegado exitosamente${NC}"
    
    echo -e "\n${YELLOW}Esperando a que los servicios se inicien...${NC}"
    sleep 5
    
    echo -e "\n${YELLOW}Estado de los servicios:${NC}"
    docker stack services ${STACK_NAME}
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}  Deployment completado${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}Accede a la aplicación web en:${NC}"
    echo -e "${GREEN}http://10.1.2.179:31793${NC}"
    echo -e "\n${YELLOW}Para ver los logs:${NC}"
    echo -e "docker service logs -f ${STACK_NAME}_master"
    echo -e "docker service logs -f ${STACK_NAME}_worker-python"
    echo -e "\n${YELLOW}Para ver el estado:${NC}"
    echo -e "docker stack ps ${STACK_NAME}"
else
    echo -e "${RED}Error al desplegar el stack${NC}"
    exit 1
fi
