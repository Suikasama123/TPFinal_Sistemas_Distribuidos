#!/bin/bash

# Script para escalar servicios de workers
set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

STACK_NAME="ai-system"

if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${YELLOW}Uso: ./scale.sh <servicio> <replicas>${NC}"
    echo -e "${YELLOW}Servicios disponibles: worker-python, worker-go, worker-java${NC}"
    echo -e "${YELLOW}Ejemplo: ./scale.sh worker-python 5${NC}"
    exit 1
fi

SERVICE=$1
REPLICAS=$2

echo -e "${YELLOW}Escalando ${SERVICE} a ${REPLICAS} réplicas...${NC}"
docker service scale ${STACK_NAME}_${SERVICE}=${REPLICAS}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Servicio escalado exitosamente${NC}"
    sleep 2
    docker service ps ${STACK_NAME}_${SERVICE}
else
    echo -e "${RED}Error al escalar servicio${NC}"
    exit 1
fi
