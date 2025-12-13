#!/bin/bash

# Script para monitorear el estado del sistema
set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STACK_NAME="ai-system"

while true; do
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Estado del Sistema AI Distribuido${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Actualizado: $(date '+%Y-%m-%d %H:%M:%S')"
    
    echo -e "\n${YELLOW}=== Servicios ===${NC}"
    docker stack services ${STACK_NAME}
    
    echo -e "\n${YELLOW}=== Tareas/Contenedores ===${NC}"
    docker stack ps ${STACK_NAME} --no-trunc
    
    echo -e "\n${BLUE}Presiona Ctrl+C para salir${NC}"
    sleep 5
done
