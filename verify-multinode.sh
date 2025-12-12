#!/bin/bash

# Script para verificar la distribución multi-nodo de los workers
set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

STACK_NAME="ai-system"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verificación Multi-Nodo${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verificar que estamos en un swarm
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${RED}❌ Docker Swarm no está activo${NC}"
    echo -e "${YELLOW}Ejecuta primero: ./swarm-init.sh${NC}"
    exit 1
fi

# 1. Listar nodos
echo -e "${CYAN}1. Nodos en el Swarm:${NC}\n"
docker node ls
TOTAL_NODES=$(docker node ls --format "{{.ID}}" | wc -l)
echo -e "\n${GREEN}Total de nodos: ${TOTAL_NODES}${NC}"

if [ $TOTAL_NODES -lt 4 ]; then
    echo -e "${YELLOW}⚠️  Solo hay ${TOTAL_NODES} nodos. Se requieren 4 nodos.${NC}"
    echo -e "${YELLOW}⚠️  Asegúrate de que todos los miembros hayan ejecutado 'docker swarm join'${NC}\n"
fi

# 2. Verificar servicios
echo -e "\n${CYAN}2. Servicios Desplegados:${NC}\n"
docker stack services $STACK_NAME

# 3. Distribución de Workers Python
echo -e "\n${CYAN}3. Distribución de Workers Python:${NC}\n"
docker service ps ${STACK_NAME}_worker-python --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"

# Contar en cuántos nodos están
NODES_PYTHON=$(docker service ps ${STACK_NAME}_worker-python --format "{{.Node}}" | sort -u | wc -l)
echo -e "\n${GREEN}Workers Python distribuidos en ${NODES_PYTHON} nodos${NC}"

# 4. Distribución de Workers Go
echo -e "\n${CYAN}4. Distribución de Workers Go:${NC}\n"
docker service ps ${STACK_NAME}_worker-go --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"

NODES_GO=$(docker service ps ${STACK_NAME}_worker-go --format "{{.Node}}" | sort -u | wc -l)
echo -e "\n${GREEN}Workers Go distribuidos en ${NODES_GO} nodos${NC}"

# 5. Distribución de Workers Java
echo -e "\n${CYAN}5. Distribución de Workers Java:${NC}\n"
docker service ps ${STACK_NAME}_worker-java --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"

NODES_JAVA=$(docker service ps ${STACK_NAME}_worker-java --format "{{.Node}}" | sort -u | wc -l)
echo -e "\n${GREEN}Workers Java distribuidos en ${NODES_JAVA} nodos${NC}"

# 6. Resumen por nodo
echo -e "\n${CYAN}6. Resumen de Containers por Nodo:${NC}\n"

for node in $(docker node ls --format "{{.Hostname}}"); do
    echo -e "${YELLOW}Nodo: ${node}${NC}"
    
    PYTHON_COUNT=$(docker service ps ${STACK_NAME}_worker-python --filter "node=${node}" --format "{{.Name}}" 2>/dev/null | wc -l)
    GO_COUNT=$(docker service ps ${STACK_NAME}_worker-go --filter "node=${node}" --format "{{.Name}}" 2>/dev/null | wc -l)
    JAVA_COUNT=$(docker service ps ${STACK_NAME}_worker-java --filter "node=${node}" --format "{{.Name}}" 2>/dev/null | wc -l)
    
    echo -e "  Worker Python: ${PYTHON_COUNT}"
    echo -e "  Worker Go: ${GO_COUNT}"
    echo -e "  Worker Java: ${JAVA_COUNT}"
    echo -e "  ${CYAN}Total: $((PYTHON_COUNT + GO_COUNT + JAVA_COUNT)) workers${NC}\n"
done

# 7. Verificación de cumplimiento
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verificación de Requerimientos${NC}"
echo -e "${BLUE}========================================${NC}\n"

ALL_OK=true

# Verificar nodos
if [ $TOTAL_NODES -ge 4 ]; then
    echo -e "${GREEN}✅ Número de nodos: ${TOTAL_NODES} (cumple: >= 4)${NC}"
else
    echo -e "${RED}❌ Número de nodos: ${TOTAL_NODES} (requiere: 4)${NC}"
    ALL_OK=false
fi

# Verificar distribución Python
if [ $NODES_PYTHON -ge 2 ]; then
    echo -e "${GREEN}✅ Workers Python distribuidos en ${NODES_PYTHON} nodos${NC}"
else
    echo -e "${YELLOW}⚠️  Workers Python solo en ${NODES_PYTHON} nodo(s)${NC}"
fi

# Verificar distribución Go
if [ $NODES_GO -ge 2 ]; then
    echo -e "${GREEN}✅ Workers Go distribuidos en ${NODES_GO} nodos${NC}"
else
    echo -e "${YELLOW}⚠️  Workers Go solo en ${NODES_GO} nodo(s)${NC}"
fi

# Verificar distribución Java
if [ $NODES_JAVA -ge 2 ]; then
    echo -e "${GREEN}✅ Workers Java distribuidos en ${NODES_JAVA} nodos${NC}"
else
    echo -e "${YELLOW}⚠️  Workers Java solo en ${NODES_JAVA} nodo(s)${NC}"
fi

echo ""

# 8. Comandos útiles
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Comandos Útiles${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Ver logs de un worker específico:${NC}"
echo -e "  docker service logs -f ${STACK_NAME}_worker-python\n"

echo -e "${YELLOW}Ver logs de un nodo específico:${NC}"
echo -e "  docker service ps ${STACK_NAME}_worker-python --filter node=NOMBRE_NODO\n"

echo -e "${YELLOW}Escalar workers (si necesitas):${NC}"
echo -e "  docker service scale ${STACK_NAME}_worker-python=6\n"

echo -e "${YELLOW}Ver estado en tiempo real:${NC}"
echo -e "  watch -n 2 'docker stack ps ${STACK_NAME}'\n"

# Resultado final
if [ $ALL_OK = true ] && [ $TOTAL_NODES -ge 4 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✅ SISTEMA MULTI-NODO VERIFICADO${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    echo -e "${GREEN}El sistema cumple con el requerimiento de${NC}"
    echo -e "${GREEN}despliegue en múltiples VMs.${NC}\n"
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  ⚠️  VERIFICACIÓN INCOMPLETA${NC}"
    echo -e "${YELLOW}========================================${NC}\n"
    echo -e "${YELLOW}Asegúrate de:${NC}"
    echo -e "  1. Tener 4 nodos unidos al Swarm"
    echo -e "  2. Haber ejecutado ./deploy.sh"
    echo -e "  3. Esperar a que todos los servicios estén Running\n"
fi
