#!/bin/bash

# Script para inicializar Docker Swarm Multi-Nodo
# Este script debe ejecutarse en el NODO MANAGER (tu nodo)

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Configuración Docker Swarm Multi-Nodo${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verificar si ya está en un swarm
if docker info | grep -q "Swarm: active"; then
    echo -e "${YELLOW}⚠️  Docker Swarm ya está activo${NC}"
    echo -e "${YELLOW}Estado actual:${NC}\n"
    docker node ls
    echo ""
    read -p "¿Deseas continuar de todos modos? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    # Obtener IP del nodo manager
    MANAGER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${YELLOW}📍 IP detectada del Manager: ${MANAGER_IP}${NC}"
    read -p "¿Es correcta esta IP? (y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        read -p "Ingresa la IP correcta del Manager: " MANAGER_IP
    fi
    
    echo -e "\n${YELLOW}🚀 Inicializando Docker Swarm...${NC}"
    docker swarm init --advertise-addr $MANAGER_IP
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Swarm inicializado exitosamente${NC}\n"
    else
        echo -e "${RED}❌ Error al inicializar Swarm${NC}"
        exit 1
    fi
fi

# Obtener token para workers
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Token para Unir Workers${NC}"
echo -e "${BLUE}========================================${NC}\n"

WORKER_TOKEN=$(docker swarm join-token worker -q)
MANAGER_ADDR=$(docker info --format '{{.Swarm.NodeAddr}}'):2377

echo -e "${GREEN}Token de Worker:${NC}"
echo -e "${YELLOW}${WORKER_TOKEN}${NC}\n"

echo -e "${GREEN}📋 Comando para ejecutar en cada nodo worker:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}docker swarm join \\${NC}"
echo -e "${YELLOW}  --token ${WORKER_TOKEN} \\${NC}"
echo -e "${YELLOW}  ${MANAGER_ADDR}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Guardar token en archivo
TOKEN_FILE="swarm-join-command.txt"
cat > $TOKEN_FILE << EOF
# Comando para unir workers al Swarm
# Ejecutar este comando en cada uno de los otros 3 nodos

docker swarm join \\
  --token ${WORKER_TOKEN} \\
  ${MANAGER_ADDR}

# Miembro 2 - Nodo Worker 1: (Agregar IP aquí)
# Miembro 3 - Nodo Worker 2: (Agregar IP aquí)
# Miembro 4 - Nodo Worker 3: (Agregar IP aquí)
EOF

echo -e "${GREEN}✅ Comando guardado en: ${TOKEN_FILE}${NC}\n"

# Instrucciones
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Próximos Pasos${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}1. Compartir el comando con los otros 3 miembros:${NC}"
echo -e "   - Enviar el archivo: ${TOKEN_FILE}"
echo -e "   - O copiar el comando de arriba\n"

echo -e "${YELLOW}2. Cada miembro debe ejecutar en SU nodo:${NC}"
echo -e "   ssh usuario@SU_NODO_IP"
echo -e "   docker swarm join --token ... MANAGER_IP:2377\n"

echo -e "${YELLOW}3. Verificar que se unieron:${NC}"
echo -e "   docker node ls\n"

echo -e "${YELLOW}4. Una vez que los 4 nodos estén unidos:${NC}"
echo -e "   ./build.sh"
echo -e "   ./deploy.sh\n"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuración Inicial Completada${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}💡 Tips:${NC}"
echo -e "   • Los 4 nodos deben poder comunicarse entre sí"
echo -e "   • Puerto 2377 debe estar abierto (Swarm management)"
echo -e "   • Puerto 7946 debe estar abierto (Swarm networking)"
echo -e "   • Puerto 4789 debe estar abierto (Overlay network)"
echo -e "   • Todos los nodos deben tener acceso al registry: 10.1.2.166:5000\n"

# Mostrar estado actual
echo -e "${YELLOW}Estado actual de nodos:${NC}"
docker node ls
