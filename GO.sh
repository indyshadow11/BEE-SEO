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
    echo "⏳ Attente 10 secondes (démarrage PostgreSQL)..."
    sleep 10
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
DB_EXISTS=$(docker exec $POSTGRES_CONTAINER psql -U admin -tc "SELECT 1 FROM pg_database WHERE datname='bythewise'" 2>/dev/null | grep -c 1 || echo "0")

if [ "$DB_EXISTS" -eq "0" ]; then
    echo "Création de la base bythewise..."
    docker exec $POSTGRES_CONTAINER psql -U admin -c "CREATE DATABASE bythewise;" 2>/dev/null
fi

echo -e "${GREEN}✓ Base de données OK${NC}"

# Initialize schema
echo "📋 Vérification des tables..."
TABLES=$(docker exec $POSTGRES_CONTAINER psql -U admin -d bythewise -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null | tr -d ' ' || echo "0")

if [ "$TABLES" -lt "5" ]; then
    echo "Initialisation du schéma..."
    docker cp api/src/config/schema.sql $POSTGRES_CONTAINER:/tmp/schema.sql
    docker exec $POSTGRES_CONTAINER psql -U admin -d bythewise -f /tmp/schema.sql 2>&1 | grep -i "create\|error" || true

    TABLES=$(docker exec $POSTGRES_CONTAINER psql -U admin -d bythewise -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null | tr -d ' ')
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
        console.log('N8N URL:', tenant.n8n_url || 'http://localhost:5678');
        console.log('═══════════════════════════════════════════════════════');
        console.log('');
        console.log('Conteneurs:');
        console.log('  N8N:', tenant.containers?.n8n || 'À créer');
        console.log('  PostgreSQL:', tenant.containers?.postgres || 'À créer');
        console.log('  Redis:', tenant.containers?.redis || 'À créer');
        console.log('');
        console.log('TENANT_ID=' + tenant.id);

        await pool.end();
        process.exit(0);
    } catch (error) {
        console.error('');
        console.error('❌ ERREUR:', error.message);
        console.error('');

        if (error.message.includes('Cannot find module')) {
            console.error('→ Problème de modules Node.js');
            console.error('→ Lance: cd api && npm install');
        } else if (error.message.includes('connect')) {
            console.error('→ Impossible de se connecter à PostgreSQL');
            console.error('→ Vérifie que PostgreSQL tourne sur port 5432');
        } else {
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

# Run it from api directory
cd api
node create-tenant-now.js
EXIT_CODE=$?
cd ..

rm -f api/create-tenant-now.js

echo ""
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ TOUT EST PRÊT !                                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Prochaines étapes:"
    echo ""
    echo "1. Lance l'API:"
    echo "   cd api && npm run dev"
    echo ""
    echo "2. Lance le Dashboard (autre terminal):"
    echo "   cd dashboard && npm run dev"
    echo ""
    echo "3. Ouvre http://localhost:3000"
    echo "   Login: demo@bythewise.com"
    echo "   Password: demo123"
    echo ""
else
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ ERREUR                                           ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Vérifie:"
    echo "1. PostgreSQL tourne: docker ps | grep postgres"
    echo "2. Port 5432 libre: lsof -i :5432"
    echo "3. Dépendances: cd api && npm install"
    echo ""
fi
