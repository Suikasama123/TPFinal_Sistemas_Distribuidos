#!/bin/bash

# Script para configurar API Keys de forma interactiva
# Uso: ./configure_keys.sh

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG_FILE="config/api_keys.json"

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Configuración de API Keys - DeepSeek AI           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar que el archivo existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Error: No se encontró $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${CYAN}📝 Instrucciones para DeepSeek (GRATIS):${NC}"
echo -e "   1. Cada miembro debe registrarse en:"
echo -e "      ${GREEN}https://platform.deepseek.com/${NC}"
echo -e "   2. Ir a 'API Keys' y crear una nueva key"
echo -e "   3. Las keys tienen formato: ${YELLOW}sk-...${NC} (comienzan con 'sk-')"
echo -e ""
echo -e "${GREEN}✨ DeepSeek es GRATIS y sin límites para uso académico${NC}"
echo -e ""
echo -e "${YELLOW}⚠️  Las keys se guardarán en: ${CONFIG_FILE}${NC}"
echo -e "${YELLOW}⚠️  Este archivo NO debe subirse a Git (ya está en .gitignore)${NC}"
echo -e ""

read -p "¿Continuar con la configuración? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Configuración cancelada${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

# Array para almacenar las keys
declare -a keys

# Solicitar las 4 keys
for i in {1..4}; do
    case $i in
        1) owner="OCHOA MOLINA, CARLOS DANIEL (10.1.2.179)" ;;
        2) owner="MENESES ZAMBRANA, CRISTIAN RODRIGO (10.1.2.163)" ;;
        3) owner="ZUBIETA HINOJOSA, ANDRE NORVAK (10.1.2.178)" ;;
        4) owner="SCHMIDT MARTINEZ, PABLO GERHARD (10.1.2.173)" ;;
    esac
    
    echo -e "\n${CYAN}API Key ${i}:${NC} ${owner}"
    echo -e "${YELLOW}Format DeepSeek: sk-...${NC}"
    
    while true; do
        read -p "Ingresa la key: " key
        
        # Validar que no esté vacía
        if [ -z "$key" ]; then
            echo -e "${RED}❌ La key no puede estar vacía${NC}"
            continue
        fi
        
        # Validar que no sea el placeholder
        if [[ "$key" == "REEMPLAZAR_CON_KEY_"* ]]; then
            echo -e "${RED}❌ Debes ingresar una key real, no el placeholder${NC}"
            continue
        fi
        
        # Validar formato básico (comienza con sk-)
        if [[ ! "$key" =~ ^sk-.+ ]]; then
            echo -e "${YELLOW}⚠️  Advertencia: La key no tiene el formato esperado (sk-...)${NC}"
            read -p "¿Usar de todas formas? (y/n): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        keys[$i]=$key
        echo -e "${GREEN}✓ Key ${i} guardada${NC}"
        break
    done
done

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📝 Generando archivo de configuración...${NC}"

# Generar el archivo JSON
cat > "$CONFIG_FILE" << EOF
{
  "ai_provider": "multi",
  "keys": [
    {
      "id": "key_1",
      "provider": "deepseek",
      "key": "${keys[1]}",
      "owner": "OCHOA MOLINA, CARLOS DANIEL (10.1.2.179)",
      "enabled": true,
      "notes": "DeepSeek - Gratis"
    },
    {
      "id": "key_2",
      "provider": "deepseek",
      "key": "${keys[2]}",
      "owner": "MENESES ZAMBRANA, CRISTIAN RODRIGO (10.1.2.163)",
      "enabled": true,
      "notes": "DeepSeek - Gratis"
    },
    {
      "id": "key_3",
      "provider": "deepseek",
      "key": "${keys[3]}",
      "owner": "ZUBIETA HINOJOSA, ANDRE NORVAK (10.1.2.178)",
      "enabled": true,
      "notes": "DeepSeek - Gratis"
    },
    {
      "id": "key_4",
      "provider": "deepseek",
      "key": "${keys[4]}",
      "owner": "SCHMIDT MARTINEZ, PABLO GERHARD (10.1.2.173)",
      "enabled": true,
      "notes": "DeepSeek - Gratis"
    }
  ],
  "distribution": {
    "strategy": "round-robin",
    "fallback_on_error": true
  },
  "provider_config": {
    "deepseek": {
      "api_url": "https://api.deepseek.com/v1/chat/completions",
      "model": "deepseek-chat",
      "max_tokens": 2048
    }
  }
}
EOF

echo -e "${GREEN}✅ Archivo de configuración generado exitosamente${NC}"
echo ""

# Mostrar resumen
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📊 Resumen de configuración:${NC}"
echo ""
for i in {1..4}; do
    key_preview="${keys[$i]:0:10}...${keys[$i]: -4}"
    echo -e "  ${GREEN}✓${NC} Key ${i}: ${key_preview}"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔍 Validando keys con DeepSeek...${NC}"
    echo ""
    
    for i in {1..4}; do
        echo -n "  Key ${i}: "
        
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${keys[$i]}" \
            -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"test"}],"max_tokens":10}' \
            "https://api.deepseek.com/v1/chat/completions")
        
        if [ "$response" == "200" ]; then
            echo -e "${GREEN}✓ OK${NC}"
        else
            echo -e "${RED}✗ Error (HTTP $response)${NC}"
        fi
    done
fi      response=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Content-Type: application/json" \
            -d '{"contents":[{"parts":[{"text":"test"}]}]}' \
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${keys[$i]}")
        
        if [ "$response" == "200" ]; then
            echo -e "${GREEN}✓ OK${NC}"
        else
            echo -e "${RED}✗ Error (HTTP $response)${NC}"
        fi
    done
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✨ Configuración completada${NC}"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo -e "  1. ${CYAN}./build.sh${NC}     - Construir imágenes"
echo -e "  2. ${CYAN}./deploy.sh${NC}    - Desplegar en Swarm"
echo ""
echo -e "${RED}⚠️  IMPORTANTE:${NC} No subas ${CONFIG_FILE} a Git"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
