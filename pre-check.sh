#!/bin/bash

# Script de verificación pre-deployment
# Verifica que todo esté listo antes de ejecutar build.sh y deploy.sh

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Verificación Pre-Deployment                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Función para verificar
check_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

check_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

check_error() {
    echo -e "${RED}✗${NC} $1"
    ERRORS=$((ERRORS + 1))
}

# 1. Verificar Docker
echo -e "${CYAN}[1/8] Verificando Docker...${NC}"
if command -v docker &> /dev/null; then
    docker_version=$(docker --version)
    check_ok "Docker instalado: $docker_version"
else
    check_error "Docker no está instalado"
fi

# 2. Verificar Docker Swarm
echo -e "\n${CYAN}[2/8] Verificando Docker Swarm...${NC}"
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    check_ok "Docker Swarm está activo"
    
    # Contar nodos
    node_count=$(docker node ls 2>/dev/null | grep -c "Ready" || echo "0")
    if [ "$node_count" -ge 4 ]; then
        check_ok "Nodos en el cluster: $node_count (cumple >= 4)"
    elif [ "$node_count" -gt 0 ]; then
        check_warning "Nodos en el cluster: $node_count (se recomienda 4)"
    else
        check_error "No se pueden contar los nodos del cluster"
    fi
else
    check_error "Docker Swarm no está activo. Ejecuta: ./swarm-init.sh"
fi

# 3. Verificar archivo de API Keys
echo -e "\n${CYAN}[3/8] Verificando API Keys...${NC}"
if [ -f "config/api_keys.json" ]; then
    check_ok "Archivo config/api_keys.json existe"
    
    # Verificar que no tenga placeholders
    if grep -q "REEMPLAZAR_CON_KEY" config/api_keys.json; then
        check_error "API keys aún tienen placeholders. Ejecuta: ./configure_keys.sh"
    else
        check_ok "API keys configuradas (sin placeholders)"
        
        # Contar keys habilitadas
        if command -v jq &> /dev/null; then
            enabled_keys=$(cat config/api_keys.json | jq '[.keys[] | select(.enabled == true)] | length')
            if [ "$enabled_keys" -ge 4 ]; then
                check_ok "Keys habilitadas: $enabled_keys"
            else
                check_warning "Keys habilitadas: $enabled_keys (se recomienda 4)"
            fi
        fi
    fi
else
    check_error "No existe config/api_keys.json. Ejecuta: ./configure_keys.sh"
fi

# 4. Verificar Registry
echo -e "\n${CYAN}[4/8] Verificando Docker Registry...${NC}"
if curl -s http://10.1.2.166:5000/v2/_catalog > /dev/null 2>&1; then
    check_ok "Registry accesible en 10.1.2.166:5000"
else
    check_warning "Registry no accesible. Puede necesitar iniciarse en el nodo manager"
fi

# 5. Verificar archivos necesarios
echo -e "\n${CYAN}[5/8] Verificando archivos del proyecto...${NC}"
required_files=(
    "docker-compose.yml"
    "build.sh"
    "deploy.sh"
    "master/Dockerfile"
    "worker-python/Dockerfile"
    "worker-go/Dockerfile"
    "worker-java/Dockerfile"
    "proto/worker.proto"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        check_ok "$file"
    else
        check_error "Falta archivo: $file"
    fi
done

# 6. Verificar permisos de scripts
echo -e "\n${CYAN}[6/8] Verificando permisos de scripts...${NC}"
scripts=(
    "build.sh"
    "deploy.sh"
    "stop.sh"
    "swarm-init.sh"
    "configure_keys.sh"
    "verify-multinode.sh"
)

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        check_ok "$script es ejecutable"
    else
        check_warning "$script no es ejecutable (chmod +x $script)"
    fi
done

# 7. Verificar espacio en disco
echo -e "\n${CYAN}[7/8] Verificando espacio en disco...${NC}"
available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$available_space" -ge 10 ]; then
    check_ok "Espacio disponible: ${available_space}GB (suficiente)"
elif [ "$available_space" -ge 5 ]; then
    check_warning "Espacio disponible: ${available_space}GB (se recomienda >= 10GB)"
else
    check_error "Espacio disponible: ${available_space}GB (insuficiente, se requiere >= 10GB)"
fi

# 8. Verificar conectividad de red
echo -e "\n${CYAN}[8/8] Verificando conectividad...${NC}"
if ping -c 1 10.1.2.166 > /dev/null 2>&1; then
    check_ok "Conectividad con 10.1.2.166"
else
    check_warning "No se puede hacer ping a 10.1.2.166"
fi

# Resumen final
echo -e "\n${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📊 Resumen:${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ TODO LISTO PARA DEPLOYMENT${NC}"
    echo ""
    echo -e "${YELLOW}Próximos pasos:${NC}"
    echo -e "  1. ${CYAN}./build.sh${NC}     - Construir imágenes (5-15 min)"
    echo -e "  2. ${CYAN}./deploy.sh${NC}    - Desplegar en Swarm"
    echo -e "  3. ${CYAN}./verify-multinode.sh${NC} - Verificar distribución"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  HAY $WARNINGS ADVERTENCIA(S)${NC}"
    echo -e "${YELLOW}Puedes continuar pero revisa las advertencias${NC}"
    echo ""
    echo -e "${YELLOW}Para continuar:${NC}"
    echo -e "  ${CYAN}./build.sh && ./deploy.sh${NC}"
    exit 0
else
    echo -e "${RED}❌ HAY $ERRORS ERROR(ES) QUE DEBEN CORREGIRSE${NC}"
    
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  También hay $WARNINGS advertencia(s)${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Acciones requeridas:${NC}"
    
    if [ ! -f "config/api_keys.json" ] || grep -q "REEMPLAZAR_CON_KEY" config/api_keys.json 2>/dev/null; then
        echo -e "  • ${CYAN}./configure_keys.sh${NC} - Configurar API keys"
    fi
    
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo -e "  • ${CYAN}./swarm-init.sh${NC} - Inicializar Docker Swarm"
    fi
    
    exit 1
fi
