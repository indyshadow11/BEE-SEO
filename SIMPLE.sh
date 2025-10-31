#!/bin/bash
###############################################################################
# VERSION ULTRA MINIMALISTE - Suppose que tu as déjà postgres-temp et redis-simple
###############################################################################

echo "🚀 Setup minimaliste..."

# 1. Créer la base
echo "1. Création base de données..."
docker exec postgres-temp psql -U admin -c "CREATE DATABASE bythewise_central;" 2>/dev/null || echo "  (déjà existe)"

# 2. Créer les tables
echo "2. Création des tables..."
docker cp api/src/config/schema.sql postgres-temp:/tmp/schema.sql
docker exec postgres-temp psql -U admin -d bythewise_central -f /tmp/schema.sql 2>&1 | grep -E "CREATE|ERROR" || echo "  ✓ OK"

# 3. Vérifier
echo "3. Vérification..."
docker exec postgres-temp psql -U admin -d bythewise_central -c "\dt"

echo ""
echo "✅ FINI ! Maintenant lance:"
echo ""
echo "   cd api && npm run dev"
echo ""
