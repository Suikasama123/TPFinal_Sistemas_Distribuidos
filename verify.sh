#!/bin/bash

# Script de verificación del sistema
set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

STACK_NAME="ai-system"
ERRORS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verificación del Sistema AI${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Función para verificar
check() {
    local name=$1
    local command=$2
    local expected=$3
    
    echo -n "Verificando $name... "
    
    if eval "$command" | grep -q "$expected"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FALLO${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# 1. Verificar Docker Swarm
check "Docker Swarm" "docker info" "Swarm: active"

# 2. Verificar que el stack existe
check "Stack desplegado" "docker stack ls" "$STACK_NAME"

# 3. Verificar servicios
echo -e "\n${YELLOW}Servicios:${NC}"
docker stack services $STACK_NAME

# 4. Verificar que Master está corriendo
check "Servicio Master" "docker service ps ${STACK_NAME}_master --format '{{.CurrentState}}'" "Running"

# 5. Verificar que Mosquitto está corriendo
check "Servicio Mosquitto" "docker service ps ${STACK_NAME}_mosquitto --format '{{.CurrentState}}'" "Running"

# 6. Verificar al menos un worker
echo -e "\n${YELLOW}Verificando Workers:${NC}"
python_workers=$(docker service ps ${STACK_NAME}_worker-python --filter "desired-state=running" -q | wc -l)
go_workers=$(docker service ps ${STACK_NAME}_worker-go --filter "desired-state=running" -q | wc -l)
java_workers=$(docker service ps ${STACK_NAME}_worker-java --filter "desired-state=running" -q | wc -l)

echo "  Python Workers: $python_workers"
echo "  Go Workers: $go_workers"
echo "  Java Workers: $java_workers"

total_workers=$((python_workers + go_workers + java_workers))
if [ $total_workers -gt 0 ]; then
    echo -e "${GREEN}✓ $total_workers workers en total${NC}"
else
    echo -e "${RED}✗ No hay workers corriendo${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 7. Verificar puerto web
echo -e "\n${YELLOW}Verificando acceso web:${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://10.1.2.179:31793 | grep -q "200"; then
    echo -e "${GREEN}✓ Web App accesible en http://10.1.2.179:31793${NC}"
else
    echo -e "${RED}✗ Web App no accesible${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 8. Verificar logs del master
echo -e "\n${YELLOW}Últimas líneas del Master:${NC}"
docker service logs --tail 5 ${STACK_NAME}_master 2>/dev/null || echo "No se pudieron obtener logs"

# 9. Verificar registro de workers
echo -e "\n${YELLOW}Verificando registro de workers:${NC}"
registered=$(docker service logs ${STACK_NAME}_master 2>/dev/null | grep -c "registrado" || echo "0")
echo "  Workers registrados detectados: $registered"

# 10. Verificar red
check "Red overlay" "docker network ls" "ai-network"

# Resumen
echo -e "\n${BLUE}========================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Todos los componentes funcionando correctamente${NC}"
    echo -e "\n${YELLOW}Acceso a la aplicación:${NC}"
    echo -e "${GREEN}http://10.1.2.179:31793${NC}"
    echo -e "\n${YELLOW}Comandos útiles:${NC}"
    echo -e "./logs.sh          - Ver logs de servicios"
    echo -e "./monitor.sh       - Monitoreo en tiempo real"
    echo -e "./scale.sh <worker> <N> - Escalar workers"
else
    echo -e "${RED}✗ Se encontraron $ERRORS errores${NC}"
    echo -e "\n${YELLOW}Sugerencias:${NC}"
    echo -e "1. Verificar logs: ./logs.sh"
    echo -e "2. Reintentar deployment: ./stop.sh && ./deploy.sh"
    echo -e "3. Verificar estado: docker stack ps ${STACK_NAME}"
fi
echo -e "${BLUE}========================================${NC}\n"

exit $ERRORS
