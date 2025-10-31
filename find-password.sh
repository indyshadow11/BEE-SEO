#!/bin/bash

echo "🔍 Détection des credentials PostgreSQL..."

CONTAINER="postgres-temp"

# Test combinations
COMBOS=(
    "postgres:"
    "admin:changeme"
    "admin:admin"
    "postgres:postgres"
    "admin:"
    "user:password"
)

for combo in "${COMBOS[@]}"; do
    USER="${combo%:*}"
    PASS="${combo#*:}"

    echo -n "Test $USER/$PASS... "

    if [ -z "$PASS" ]; then
        if docker exec $CONTAINER psql -U $USER -d bythewise_central -c "SELECT 1" > /dev/null 2>&1; then
            echo "✓ TROUVÉ !"
            echo ""
            echo "Credentials:"
            echo "  User: $USER"
            echo "  Password: (vide)"
            echo ""
            echo "Mise à jour de api/.env..."
            sed -i '' "s/POSTGRES_USER=.*/POSTGRES_USER=$USER/" api/.env
            sed -i '' "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=/" api/.env
            echo "✓ Fait !"
            exit 0
        fi
    else
        if PGPASSWORD=$PASS docker exec $CONTAINER psql -U $USER -d bythewise_central -c "SELECT 1" > /dev/null 2>&1; then
            echo "✓ TROUVÉ !"
            echo ""
            echo "Credentials:"
            echo "  User: $USER"
            echo "  Password: $PASS"
            echo ""
            echo "Mise à jour de api/.env..."
            sed -i '' "s/POSTGRES_USER=.*/POSTGRES_USER=$USER/" api/.env
            sed -i '' "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$PASS/" api/.env
            echo "✓ Fait !"
            exit 0
        fi
    fi

    echo "✗"
done

echo ""
echo "❌ Aucune combinaison ne fonctionne"
echo ""
echo "Entre les credentials manuellement:"
read -p "Username: " MANUAL_USER
read -sp "Password: " MANUAL_PASS
echo ""

sed -i '' "s/POSTGRES_USER=.*/POSTGRES_USER=$MANUAL_USER/" api/.env
sed -i '' "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$MANUAL_PASS/" api/.env

echo "✓ api/.env mis à jour"
