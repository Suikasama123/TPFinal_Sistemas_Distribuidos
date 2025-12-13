#!/bin/bash

# Script para detener y eliminar el stack
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

STACK_NAME="ai-system"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Deteniendo stack ${STACK_NAME}${NC}"
echo -e "${YELLOW}========================================${NC}"

# Eliminar el stack
docker stack rm ${STACK_NAME}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Stack eliminado exitosamente${NC}"
    echo -e "${YELLOW}Esperando a que los contenedores terminen...${NC}"
    
    # Esperar a que todos los contenedores se detengan
    sleep 10
    
    echo -e "${GREEN}Stack detenido completamente${NC}"
else
    echo -e "${RED}Error al eliminar el stack${NC}"
    exit 1
fi
