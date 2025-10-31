#!/bin/bash

###############################################################################
# BYTHEWISE SaaS - Test rapide de connexion
###############################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Test de connexion rapide..."
echo ""

# Load .env
if [ -f "api/.env" ]; then
    export $(cat api/.env | grep -v '^#' | xargs 2>/dev/null)
else
    echo -e "${RED}✗ Fichier api/.env introuvable${NC}"
    exit 1
fi

# Find PostgreSQL container
POSTGRES_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i postgres | head -1)
if [ -z "$POSTGRES_CONTAINER" ]; then
    echo -e "${RED}✗ Aucun conteneur PostgreSQL trouvé${NC}"
    echo "Conteneurs actifs:"
    docker ps --format "  {{.Names}} ({{.Image}})"
    exit 1
fi

echo -e "${GREEN}✓ Conteneur PostgreSQL: ${POSTGRES_CONTAINER}${NC}"

# Test connection
echo "Testing connection to database '${POSTGRES_DB}'..."
if docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connexion OK${NC}"
else
    echo -e "${RED}✗ Connexion échouée${NC}"
    echo ""
    echo "Essayez :"
    echo "1. Vérifier les credentials dans api/.env"
    echo "2. Lancer: ./scripts/diagnose-and-fix.sh"
    exit 1
fi

# Check tables
TABLES=$(docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null | tr -d ' ')

if [ "$TABLES" -gt "0" ]; then
    echo -e "${GREEN}✓ Tables trouvées: ${TABLES}${NC}"
    docker exec ${POSTGRES_CONTAINER} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\dt"
else
    echo -e "${YELLOW}⚠ Aucune table trouvée${NC}"
    echo "Lancez: ./scripts/diagnose-and-fix.sh"
    exit 1
fi

# Find Redis container
REDIS_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i redis | head -1)
if [ -z "$REDIS_CONTAINER" ]; then
    echo -e "${YELLOW}⚠ Aucun conteneur Redis trouvé${NC}"
else
    echo -e "${GREEN}✓ Conteneur Redis: ${REDIS_CONTAINER}${NC}"
    if docker exec ${REDIS_CONTAINER} redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Redis OK${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✅ Tout est prêt ! Vous pouvez lancer:${NC}"
echo "   ./scripts/create-tenant-debug.sh \"Premier Client\" starter"
