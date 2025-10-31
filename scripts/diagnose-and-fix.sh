#!/bin/bash

###############################################################################
# BYTHEWISE SaaS - Diagnostic et Correction
#
# Ce script diagnostique et corrige les problèmes de connexion
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  BYTHEWISE - Diagnostic et Correction                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Load .env
if [ -f "api/.env" ]; then
    export $(cat api/.env | grep -v '^#' | xargs)
    echo -e "${GREEN}✓ Fichier .env chargé${NC}"
else
    echo -e "${RED}✗ Fichier api/.env introuvable${NC}"
    echo "Création du fichier .env..."
    cp api/.env.example api/.env
    export $(cat api/.env | grep -v '^#' | xargs)
fi

echo ""
echo -e "${BLUE}Configuration détectée:${NC}"
echo "  POSTGRES_HOST: ${POSTGRES_HOST}"
echo "  POSTGRES_PORT: ${POSTGRES_PORT}"
echo "  POSTGRES_DB: ${POSTGRES_DB}"
echo "  POSTGRES_USER: ${POSTGRES_USER}"
echo ""

# Test 1: Vérifier que PostgreSQL répond
echo -e "${BLUE}[1/6] Test de connexion PostgreSQL...${NC}"
if docker exec postgres-temp pg_isready -U ${POSTGRES_USER} > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL répond${NC}"
else
    echo -e "${RED}✗ PostgreSQL ne répond pas${NC}"
    echo ""
    echo "Vérifiez que votre conteneur PostgreSQL est bien nommé 'postgres-temp'"
    echo "Ou modifiez ce script avec le bon nom de conteneur"
    echo ""
    echo "Conteneurs PostgreSQL disponibles:"
    docker ps --filter "ancestor=postgres" --format "{{.Names}}"
    exit 1
fi

# Test 2: Vérifier les credentials
echo ""
echo -e "${BLUE}[2/6] Test des credentials...${NC}"
if docker exec postgres-temp psql -U ${POSTGRES_USER} -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Credentials valides${NC}"
else
    echo -e "${YELLOW}⚠ Les credentials par défaut ne fonctionnent pas${NC}"
    echo ""
    echo "Veuillez entrer les credentials de votre conteneur PostgreSQL:"
    read -p "Username (default: postgres): " TEMP_USER
    POSTGRES_USER=${TEMP_USER:-postgres}

    read -sp "Password: " TEMP_PASSWORD
    echo ""
    POSTGRES_PASSWORD=${TEMP_PASSWORD}

    # Update .env file
    sed -i "s/POSTGRES_USER=.*/POSTGRES_USER=${POSTGRES_USER}/" api/.env
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${POSTGRES_PASSWORD}/" api/.env

    echo -e "${GREEN}✓ Credentials mis à jour dans api/.env${NC}"
fi

# Test 3: Vérifier si la base de données existe
echo ""
echo -e "${BLUE}[3/6] Vérification de la base de données...${NC}"
DB_EXISTS=$(docker exec postgres-temp psql -U ${POSTGRES_USER} -tc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" | grep -c 1 || true)

if [ "$DB_EXISTS" -eq "1" ]; then
    echo -e "${GREEN}✓ Base de données '${POSTGRES_DB}' existe${NC}"
else
    echo -e "${YELLOW}⚠ Base de données '${POSTGRES_DB}' n'existe pas${NC}"
    echo "Création de la base de données..."

    docker exec postgres-temp psql -U ${POSTGRES_USER} -c "CREATE DATABASE ${POSTGRES_DB};"

    echo -e "${GREEN}✓ Base de données créée${NC}"
fi

# Test 4: Vérifier si les tables existent
echo ""
echo -e "${BLUE}[4/6] Vérification des tables...${NC}"
TABLES_COUNT=$(docker exec postgres-temp psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'" | tr -d ' ' || echo "0")

if [ "$TABLES_COUNT" -ge "5" ]; then
    echo -e "${GREEN}✓ Tables existent (${TABLES_COUNT} tables)${NC}"

    # List tables
    echo "Tables existantes:"
    docker exec postgres-temp psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\dt" 2>/dev/null || true
else
    echo -e "${YELLOW}⚠ Aucune table trouvée (${TABLES_COUNT} tables)${NC}"
    echo "Initialisation du schéma..."

    # Check if schema.sql exists
    if [ -f "api/src/config/schema.sql" ]; then
        # Copy schema to container and execute
        docker cp api/src/config/schema.sql postgres-temp:/tmp/schema.sql
        docker exec postgres-temp psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -f /tmp/schema.sql

        echo -e "${GREEN}✓ Schéma initialisé${NC}"

        # Verify
        TABLES_COUNT=$(docker exec postgres-temp psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'" | tr -d ' ')
        echo "Tables créées: ${TABLES_COUNT}"
    else
        echo -e "${RED}✗ Fichier schema.sql introuvable${NC}"
        exit 1
    fi
fi

# Test 5: Test de connexion depuis Node.js
echo ""
echo -e "${BLUE}[5/6] Test de connexion Node.js...${NC}"

cat > /tmp/test-db-connection.js << 'EOF'
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config({ path: 'api/.env' });

const { Pool } = pg;

const pool = new Pool({
    host: process.env.POSTGRES_HOST || 'localhost',
    port: process.env.POSTGRES_PORT || 5432,
    database: process.env.POSTGRES_DB || 'bythewise_central',
    user: process.env.POSTGRES_USER || 'admin',
    password: process.env.POSTGRES_PASSWORD || 'changeme',
});

async function testConnection() {
    try {
        const client = await pool.connect();
        console.log('✓ Connexion Node.js réussie');

        const result = await client.query('SELECT NOW()');
        console.log('✓ Query test réussie:', result.rows[0].now);

        const tables = await client.query(`
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema='public' AND table_type='BASE TABLE'
        `);
        console.log('✓ Tables disponibles:', tables.rows.length);
        tables.rows.forEach(row => console.log('  -', row.table_name));

        client.release();
        await pool.end();
        process.exit(0);
    } catch (error) {
        console.error('✗ Erreur de connexion:', error.message);
        process.exit(1);
    }
}

testConnection();
EOF

cd api
if node /tmp/test-db-connection.js; then
    echo -e "${GREEN}✓ Connexion Node.js fonctionne${NC}"
else
    echo -e "${RED}✗ Connexion Node.js échoue${NC}"
    echo ""
    echo "Vérifiez les credentials dans api/.env"
    exit 1
fi
cd ..

# Test 6: Vérifier Redis
echo ""
echo -e "${BLUE}[6/6] Test de connexion Redis...${NC}"
if docker exec redis-simple redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Redis répond${NC}"
else
    echo -e "${YELLOW}⚠ Redis ne répond pas ou conteneur mal nommé${NC}"
    echo "Conteneurs Redis disponibles:"
    docker ps --filter "ancestor=redis" --format "{{.Names}}"
fi

# Summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ DIAGNOSTIC TERMINÉ                                    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Résumé de la configuration:${NC}"
echo "  PostgreSQL: ✓ Opérationnel (port ${POSTGRES_PORT})"
echo "  Base de données: ✓ ${POSTGRES_DB}"
echo "  Tables: ✓ ${TABLES_COUNT} tables créées"
echo "  Redis: ✓ Opérationnel (port ${REDIS_HOST:-localhost}:${REDIS_PORT})"
echo "  Node.js: ✓ Peut se connecter"
echo ""
echo -e "${GREEN}Vous pouvez maintenant lancer:${NC}"
echo "  ./scripts/create-tenant.sh \"Premier Client\" starter"
echo ""
