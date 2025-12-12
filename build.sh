#!/bin/bash

# Script para construir y subir todas las imágenes al registry
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Construyendo y subiendo imágenes${NC}"
echo -e "${GREEN}========================================${NC}"

# Leer información del cluster
REGISTRY="10.1.2.166:5000"
echo -e "${YELLOW}Registry: ${REGISTRY}${NC}"

# Función para construir y subir imagen
build_and_push() {
    local service=$1
    local context=$2
    local image="${REGISTRY}/${service}:latest"
    
    echo -e "\n${YELLOW}[${service}] Construyendo imagen...${NC}"
    
    # Para el master, copiar config temporalmente
    if [ "$service" == "master" ]; then
        echo -e "${YELLOW}[${service}] Copiando configuración...${NC}"
        mkdir -p master/config
        cp -r config/* master/config/ 2>/dev/null || true
    fi
    
    docker build -t ${image} ${context}
    
    # Limpiar archivos temporales del master
    if [ "$service" == "master" ]; then
        rm -rf master/config
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[${service}] Imagen construida exitosamente${NC}"
        
        echo -e "${YELLOW}[${service}] Subiendo al registry...${NC}"
        docker push ${image}
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[${service}] Imagen subida exitosamente${NC}"
        else
            echo -e "${RED}[${service}] Error al subir imagen${NC}"
            return 1
        fi
    else
        echo -e "${RED}[${service}] Error al construir imagen${NC}"
        return 1
    fi
}

# Construir y subir Master
build_and_push "master" "./master"

# Construir y subir Workers
build_and_push "worker-python" "./worker-python"
build_and_push "worker-go" "./worker-go"
build_and_push "worker-java" "./worker-java"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Todas las imágenes construidas y subidas${NC}"
echo -e "${GREEN}========================================${NC}"
