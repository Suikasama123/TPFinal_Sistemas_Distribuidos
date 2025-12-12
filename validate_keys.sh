#!/bin/bash

# Script para validar que las API keys funcionan
set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="config/api_keys.json"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validador de API Keys${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verificar que existe el archivo
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Error: No se encontró $CONFIG_FILE${NC}"
    echo -e "${YELLOW}💡 Copia el archivo ejemplo:${NC}"
    echo -e "   cp config/api_keys.example.json config/api_keys.json"
    exit 1
fi

# Leer el archivo JSON
echo -e "${YELLOW}📖 Leyendo configuración...${NC}\n"

# Contar keys
total_keys=$(cat $CONFIG_FILE | grep -o '"key":' | wc -l)
echo -e "${BLUE}📊 Total de keys configuradas: ${total_keys}${NC}"

# Validar cada key
echo -e "\n${YELLOW}🔍 Validando keys...${NC}\n"

# Usar jq si está disponible, sino parsing básico
if command -v jq &> /dev/null; then
    # Con jq (más robusto)
    keys_array=$(cat $CONFIG_FILE | jq -r '.keys[] | select(.enabled == true) | @base64')
    
    count=0
    for key_encoded in $keys_array; do
        key_data=$(echo $key_encoded | base64 --decode)
        
        key_id=$(echo $key_data | jq -r '.id')
        key_value=$(echo $key_data | jq -r '.key')
        key_owner=$(echo $key_data | jq -r '.owner')
        key_provider=$(echo $key_data | jq -r '.provider')
        
        count=$((count + 1))
        
        echo -e "${BLUE}[$count] Validando: ${key_id}${NC}"
        echo -e "    Owner: ${key_owner}"
        echo -e "    Provider: ${key_provider}"
        
        # Verificar que no sea el placeholder
        if [[ "$key_value" == "REEMPLAZAR_CON_KEY"* ]]; then
            echo -e "    Status: ${RED}❌ KEY NO CONFIGURADA${NC}"
            echo -e "    ${YELLOW}⚠️  Debes reemplazar el placeholder con una key real${NC}\n"
            continue
        fi
        
        # Verificar formato básico
        if [ ${#key_value} -lt 20 ]; then
            echo -e "    Status: ${RED}❌ KEY INVÁLIDA (muy corta)${NC}\n"
            continue
        fi
        
        # Test simple de API (solo para Gemini)
        if [ "$key_provider" == "gemini" ]; then
            echo -e "    ${YELLOW}🧪 Probando conexión con Gemini...${NC}"
            
            response=$(curl -s -w "\n%{http_code}" \
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${key_value}" \
                -H 'Content-Type: application/json' \
                -d '{
                  "contents": [{
                    "parts":[{"text": "Responde solo con: OK"}]
                  }]
                }' 2>/dev/null)
            
            http_code=$(echo "$response" | tail -n1)
            
            if [ "$http_code" == "200" ]; then
                echo -e "    Status: ${GREEN}✅ KEY VÁLIDA Y FUNCIONAL${NC}\n"
            else
                echo -e "    Status: ${RED}❌ ERROR (HTTP $http_code)${NC}"
                echo -e "    ${YELLOW}⚠️  Verifica que la key sea correcta${NC}\n"
            fi
        else
            echo -e "    Status: ${YELLOW}⏭️  VALIDACIÓN MANUAL (provider: ${key_provider})${NC}\n"
        fi
    done
else
    # Sin jq (parsing básico)
    echo -e "${YELLOW}⚠️  jq no está instalado, validación básica solamente${NC}\n"
    
    grep -o '"key": "[^"]*"' $CONFIG_FILE | while read -r line; do
        key_value=$(echo $line | cut -d'"' -f4)
        
        if [[ "$key_value" == "REEMPLAZAR_CON_KEY"* ]]; then
            echo -e "${RED}❌ Key no configurada: $key_value${NC}"
        elif [ ${#key_value} -lt 20 ]; then
            echo -e "${RED}❌ Key inválida (muy corta): ${key_value:0:10}...${NC}"
        else
            echo -e "${GREEN}✅ Key configurada: ${key_value:0:15}...${NC}"
        fi
    done
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Validación completada${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}💡 Consejos:${NC}"
echo -e "   • Verifica que todas las keys estén configuradas"
echo -e "   • Prueba el sistema completo con: ${GREEN}./deploy.sh${NC}"
echo -e "   • Para obtener keys: ${BLUE}https://aistudio.google.com/api-keys${NC}\n"
