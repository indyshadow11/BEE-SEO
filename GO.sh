#!/bin/bash

###############################################################################
# BYTHEWISE - SCRIPT ULTRA SIMPLE QUI FAIT TOUT
# Lance ça et c'est fini : ./GO.sh
###############################################################################

set +e  # Continue même en cas d'erreur

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  BYTHEWISE - SETUP AUTOMATIQUE                      ║${NC}"
echo -e "${BLUE}║  Je m'occupe de TOUT !                              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect PostgreSQL container
echo "🔍 Recherche du conteneur PostgreSQL..."
POSTGRES_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i postgres | head -1)

if [ -z "$POSTGRES_CONTAINER" ]; then
    echo -e "${YELLOW}Aucun PostgreSQL trouvé. Je le crée...${NC}"
    docker run -d \
        --name bythewise-postgres \
        -e POSTGRES_USER=admin \
        -e POSTGRES_PASSWORD=changeme \
        -e POSTGRES_DB=bythewise_central \
        -p 5432:5432 \
        postgres:15-alpine

    POSTGRES_CONTAINER="bythewise-postgres"
    echo "⏳ Attente que PostgreSQL soit prêt..."

    # Wait for PostgreSQL to be ready (max 30 seconds)
    for i in {1..30}; do
        if docker exec $POSTGRES_CONTAINER pg_isready -U admin >/dev/null 2>&1; then
            echo -e "${GREEN}✓ PostgreSQL prêt après ${i}s${NC}"
            break
        fi
        sleep 1
    done
fi

echo -e "${GREEN}✓ PostgreSQL: $POSTGRES_CONTAINER${NC}"

# Detect Redis
echo "🔍 Recherche du conteneur Redis..."
REDIS_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i redis | head -1)

if [ -z "$REDIS_CONTAINER" ]; then
    echo -e "${YELLOW}Aucun Redis trouvé. Je le crée...${NC}"
    docker run -d \
        --name bythewise-redis \
        -p 6379:6379 \
        redis:7-alpine

    REDIS_CONTAINER="bythewise-redis"
    sleep 5
fi

echo -e "${GREEN}✓ Redis: $REDIS_CONTAINER${NC}"
echo ""

# Create database if not exists
echo "📦 Vérification de la base de données..."
DB_EXISTS=$(docker exec $POSTGRES_CONTAINER psql -U admin -d postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -w bythewise | wc -l | tr -d ' ')

if [ "$DB_EXISTS" = "0" ]; then
    echo "Création de la base bythewise..."
    docker exec $POSTGRES_CONTAINER psql -U admin -d postgres -c "CREATE DATABASE bythewise;"
fi

echo -e "${GREEN}✓ Base de données OK${NC}"

# Initialize schema
echo "📋 Vérification des tables..."
TABLES=$(docker exec $POSTGRES_CONTAINER psql -U admin -d bythewise -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>&1)

# Clean up the output
TABLES=$(echo "$TABLES" | tr -d ' \n\r')

if [ -z "$TABLES" ] || [ "$TABLES" = "0" ]; then
    echo "Initialisation du schéma..."
    docker cp api/src/config/schema.sql $POSTGRES_CONTAINER:/tmp/schema.sql
    docker exec $POSTGRES_CONTAINER psql -U admin -d bythewise -f /tmp/schema.sql

    TABLES=$(docker exec $POSTGRES_CONTAINER psql -U admin -d bythewise -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>&1 | tr -d ' \n\r')
fi

echo -e "${GREEN}✓ Tables créées: $TABLES${NC}"
echo ""

# Update .env with correct values
echo "⚙️  Configuration de l'environnement..."
cat > api/.env << 'EOF'
NODE_ENV=development
PORT=3001
HOST=0.0.0.0
LOG_LEVEL=info

CORS_ORIGIN=http://localhost:3000

JWT_SECRET=change-this-secret-in-production

POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=bythewise
POSTGRES_USER=admin
POSTGRES_PASSWORD=changeme

REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

DOCKER_SOCKET=/var/run/docker.sock
EOF

echo -e "${GREEN}✓ Configuration OK${NC}"
echo ""

# Install dependencies if needed
if [ ! -d "api/node_modules" ]; then
    echo "📦 Installation des dépendances..."
    cd api && npm install --silent > /dev/null 2>&1 && cd ..
    echo -e "${GREEN}✓ Dépendances installées${NC}"
fi

# Create tenant
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CRÉATION DU TENANT                                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Simple Node.js script dans le dossier api
cat > api/create-tenant-now.js << 'EOFJS'
import { createTenant } from './src/services/orchestrator.js';
import pg from 'pg';

const pool = new pg.Pool({
    host: 'localhost',
    port: 5432,
    database: 'bythewise',
    user: 'admin',
    password: 'changeme',
});

async function go() {
    try {
        // Quick test
        await pool.query('SELECT 1');
        console.log('✓ Connexion DB OK');

        // Create tenant
        console.log('');
        console.log('Création du tenant...');
        const tenant = await createTenant('Premier Client', 'starter');

        console.log('');
        console.log('═══════════════════════════════════════════════════════');
        console.log('🎉 TENANT CRÉÉ AVEC SUCCÈS !');
        console.log('═══════════════════════════════════════════════════════');
        console.log('ID:', tenant.id);
        console.log('Nom:', tenant.name);
        console.log('Subdomain:', tenant.subdomain);
        console.log('Plan:', tenant.plan);
        console.log('N8N URL:', tenant.n8n_url);
        console.log('═══════════════════════════════════════════════════════');
        console.log('');
        console.log('Les conteneurs sont en cours de démarrage...');
        console.log('N8N sera accessible dans quelques minutes.');
        console.log('');
        process.exit(0);
    } catch (error) {
        console.error('');
        console.error('❌ ERREUR:', error.message);
        console.error('');
        if (error.stack) {
            console.error('Stack:', error.stack);
        }
        process.exit(1);
    }
}

setTimeout(() => {
    console.error('⏱️ TIMEOUT après 120 secondes');
    process.exit(1);
}, 120000);

go();
EOFJS

# Run the script
cd api && node create-tenant-now.js
EXIT_CODE=$?
cd ..

# Cleanup
rm -f api/create-tenant-now.js

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ SUCCÈS !                                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Pour vérifier les conteneurs:"
    echo "  docker ps | grep tenant"
    echo ""
    echo "Pour voir les logs:"
    echo "  docker logs -f n8n-tenant-<ID>"
    echo ""
else
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ ERREUR                                           ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Vérifie:"
    echo "1. PostgreSQL tourne: docker ps | grep postgres"
    echo "2. Port 5432 libre: lsof -i :5432"
    echo "3. Dépendances: cd api && npm install"
    echo ""
    exit 1
fi
