#!/bin/bash

# Script para ver los logs de los servicios
set -e

STACK_NAME="ai-system"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Servicios disponibles:${NC}"
docker stack services ${STACK_NAME}

echo -e "\n${YELLOW}Selecciona un servicio para ver sus logs:${NC}"
echo "1) Master"
echo "2) Worker Python"
echo "3) Worker Go"
echo "4) Worker Java"
echo "5) Mosquitto"
echo "6) Todos"

read -p "Opción: " option

case $option in
    1)
        docker service logs -f ${STACK_NAME}_master
        ;;
    2)
        docker service logs -f ${STACK_NAME}_worker-python
        ;;
    3)
        docker service logs -f ${STACK_NAME}_worker-go
        ;;
    4)
        docker service logs -f ${STACK_NAME}_worker-java
        ;;
    5)
        docker service logs -f ${STACK_NAME}_mosquitto
        ;;
    6)
        echo -e "${YELLOW}Mostrando logs de todos los servicios (últimas 50 líneas)${NC}"
        for service in master worker-python worker-go worker-java mosquitto; do
            echo -e "\n${GREEN}=== ${service} ===${NC}"
            docker service logs --tail 50 ${STACK_NAME}_${service}
        done
        ;;
    *)
        echo "Opción inválida"
        exit 1
        ;;
esac
