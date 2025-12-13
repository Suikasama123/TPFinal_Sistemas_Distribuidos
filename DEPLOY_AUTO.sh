#!/bin/bash
# EJECUTAR ESTO EN EL CLUSTER (NODO MANAGER)

echo "=========================================="
echo "  DEPLOYMENT AUTOMÁTICO - Sistemas Distribuidos"
echo "=========================================="
echo ""

# 1. Verificar pre-requisitos
echo "📋 [1/5] Verificando pre-requisitos..."
./pre-check.sh
if [ $? -ne 0 ]; then
    echo "❌ Pre-check falló. Revisa los errores arriba."
    echo "💡 Si Swarm no está activo, ejecuta: ./swarm-init.sh"
    exit 1
fi
echo ""

# 2. Verificar Swarm
echo "🔍 [2/5] Verificando Docker Swarm..."
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "⚠️  Docker Swarm no está activo."
    echo "🚀 Inicializando Swarm..."
    ./swarm-init.sh
    echo ""
    echo "📝 ACCIÓN REQUERIDA:"
    echo "   1. Comparte el comando de join con tus 3 compañeros"
    echo "   2. Espera a que ejecuten: docker swarm join ..."
    echo "   3. Verifica con: docker node ls"
    echo "   4. Cuando veas 4 nodos, ejecuta este script de nuevo"
    exit 0
fi

# Verificar número de nodos
NODE_COUNT=$(docker node ls 2>/dev/null | grep -c "Ready" || echo "0")
echo "✅ Swarm activo con $NODE_COUNT nodos"

if [ "$NODE_COUNT" -lt 4 ]; then
    echo "⚠️  Solo hay $NODE_COUNT nodos. Se necesitan 4."
    echo "💡 Asegúrate de que tus compañeros hayan ejecutado: docker swarm join ..."
    read -p "¿Continuar de todas formas? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi
echo ""

# 3. Build
echo "🔨 [3/5] Construyendo imágenes Docker..."
echo "⏱️  Esto tomará 5-15 minutos..."
./build.sh
if [ $? -ne 0 ]; then
    echo "❌ Build falló"
    exit 1
fi
echo ""

# 4. Deploy
echo "🚀 [4/5] Desplegando en el cluster..."
./deploy.sh
if [ $? -ne 0 ]; then
    echo "❌ Deploy falló"
    exit 1
fi
echo ""

# 5. Verificar
echo "✅ [5/5] Verificando deployment..."
sleep 10
./verify-multinode.sh

echo ""
echo "=========================================="
echo "  ✅ DEPLOYMENT COMPLETADO"
echo "=========================================="
echo ""
echo "🌐 Accede a la aplicación en:"
echo "   http://10.1.2.179:31793"
echo ""
echo "📊 Comandos útiles:"
echo "   docker stack services ai-system    - Ver servicios"
echo "   ./logs.sh                          - Ver logs"
echo "   ./monitor.sh                       - Monitorear"
echo "   ./stop.sh                          - Detener todo"
echo ""
