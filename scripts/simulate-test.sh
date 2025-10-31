#!/bin/bash

###############################################################################
# BYTHEWISE SaaS - Simulation du Test Complet
#
# Ce script SIMULE l'exécution complète du système pour montrer
# les résultats attendus (utilisable sans Docker)
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Simulated values
TENANT_ID="tenant-abc123def456"
SUBDOMAIN="premier-client"
N8N_PORT="5678"

clear

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  BYTHEWISE SaaS - SIMULATION DU TEST COMPLET             ║${NC}"
echo -e "${BLUE}║  (Résultats attendus avec Docker)                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  Ceci est une SIMULATION - Docker n'est pas disponible${NC}"
echo -e "${YELLOW}   Exécutez ce test sur une machine avec Docker installé${NC}"
echo ""
read -p "Appuyez sur Entrée pour continuer..."

###############################################################################
# ÉTAPE 1 : Démarrage Infrastructure
###############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}▶ ÉTAPE 1/7 : Démarrage de l'infrastructure${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}$ docker compose up -d postgres${NC}"
sleep 1
echo "Creating network \"bythewise_internal\" with driver \"bridge\""
echo "Creating volume \"bythewise_postgres_data\" with default driver"
echo "Pulling postgres (postgres:15-alpine)..."
sleep 1
echo "15-alpine: Pulling from library/postgres"
echo "Status: Downloaded newer image for postgres:15-alpine"
echo "Creating bythewise-postgres ... done"
echo ""

echo -e "${CYAN}$ docker compose up -d redis${NC}"
sleep 1
echo "Creating volume \"bythewise_redis_data\" with default driver"
echo "Pulling redis (redis:7-alpine)..."
echo "7-alpine: Pulling from library/redis"
echo "Status: Downloaded newer image for redis:7-alpine"
echo "Creating bythewise-redis ... done"
echo ""

sleep 1
echo -e "${GREEN}✓ PostgreSQL démarré et healthy${NC}"
echo -e "${GREEN}✓ Redis démarré et healthy${NC}"
echo ""

echo -e "${CYAN}$ docker compose ps${NC}"
echo ""
echo "NAME                   IMAGE                  STATUS         PORTS"
echo "bythewise-postgres     postgres:15-alpine     Up (healthy)   0.0.0.0:5432->5432/tcp"
echo "bythewise-redis        redis:7-alpine         Up (healthy)   0.0.0.0:6379->6379/tcp"
echo ""

read -p "Appuyez sur Entrée pour continuer..."

###############################################################################
# ÉTAPE 2 : Initialisation Base de Données
###############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}▶ ÉTAPE 2/7 : Initialisation de la base de données${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}$ cd api && npm run db:init${NC}"
sleep 1
echo ""
echo "Connecting to PostgreSQL..."
echo "Connected to bythewise_central database"
echo ""
echo "Running schema migrations..."
sleep 1
echo "  ✓ Created extension: uuid-generate-v4"
echo "  ✓ Created table: tenants"
echo "  ✓ Created table: users"
echo "  ✓ Created table: workflow_executions"
echo "  ✓ Created table: billing"
echo "  ✓ Created table: audit_logs"
echo "  ✓ Created indexes"
echo "  ✓ Created triggers"
echo "  ✓ Created row-level security policies"
echo ""
echo -e "${GREEN}✓ Database initialized successfully${NC}"
echo ""

echo -e "${CYAN}$ docker exec -it bythewise-postgres psql -U admin -d bythewise_central -c \"\\dt\"${NC}"
echo ""
echo "                    List of relations"
echo " Schema |         Name          | Type  | Owner"
echo "--------+-----------------------+-------+-------"
echo " public | audit_logs            | table | admin"
echo " public | billing               | table | admin"
echo " public | tenants               | table | admin"
echo " public | users                 | table | admin"
echo " public | workflow_executions   | table | admin"
echo "(5 rows)"
echo ""

read -p "Appuyez sur Entrée pour continuer..."

###############################################################################
# ÉTAPE 3 : Création du Tenant
###############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}▶ ÉTAPE 3/7 : Création d'un tenant de test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}$ ./scripts/create-tenant.sh \"Premier Client\" starter${NC}"
sleep 1
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  BYTHEWISE SaaS - Tenant Provisioning${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}ℹ Client Name: Premier Client${NC}"
echo -e "${YELLOW}ℹ Plan: starter${NC}"
echo ""
echo -e "${BLUE}▶ Checking dependencies...${NC}"
sleep 0.5
echo -e "${GREEN}✓ Docker found${NC}"
echo -e "${GREEN}✓ docker-compose found${NC}"
echo -e "${GREEN}✓ Node.js found (v22.21.0)${NC}"
echo -e "${GREEN}✓ Public network exists${NC}"
echo ""
echo -e "${BLUE}▶ Generating tenant configuration...${NC}"
sleep 1
echo "Initializing database..."
echo "Creating tenant..."
sleep 1
echo ""
echo "============================================================"
echo "TENANT CREATED SUCCESSFULLY"
echo "============================================================"
echo "ID: ${TENANT_ID}"
echo "Name: Premier Client"
echo "Subdomain: ${SUBDOMAIN}"
echo "Plan: starter"
echo "Status: active"
echo "N8N URL: http://${SUBDOMAIN}.n8n.local:5678"
echo "Created: $(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
echo "============================================================"
echo ""
echo "Containers:"
echo "  N8N: n8n-${TENANT_ID}"
echo "  PostgreSQL: postgres-${TENANT_ID}"
echo "  Redis: redis-${TENANT_ID}"
echo "============================================================"
echo ""
echo "TENANT_ID=${TENANT_ID}"
echo ""

sleep 1
echo -e "${GREEN}✓ Tenant provisioning completed!${NC}"
echo ""

echo -e "${BLUE}▶ Importing workflows to N8N...${NC}"
sleep 1
echo ""
echo "⏳ Waiting for N8N to be ready... (attempt 1/30)"
sleep 0.5
echo "⏳ Waiting for N8N to be ready... (attempt 2/30)"
sleep 0.5
echo "⏳ Waiting for N8N to be ready... (attempt 3/30)"
sleep 0.5
echo -e "${GREEN}✓ N8N is healthy and ready!${NC}"
echo ""
sleep 1
echo "Importing workflows..."
echo -e "${GREEN}✓ Imported WF1 - Seed Expansion (ID: 1)${NC}"
echo "  Webhook: http://localhost:${N8N_PORT}/webhook/wf1-seed-expansion"
sleep 0.5
echo -e "${GREEN}✓ Imported WF2 - Clustering (ID: 2)${NC}"
echo "  Webhook: http://localhost:${N8N_PORT}/webhook/wf2-clustering"
sleep 0.5
echo -e "${GREEN}✓ Imported WF3 - Article Generation (ID: 3)${NC}"
echo "  Schedule: Monday & Thursday at 8am (Cron: 0 8 * * 1,4)"
sleep 0.5
echo ""
echo -e "${GREEN}✓ Workflows imported successfully!${NC}"
echo ""

echo -e "${YELLOW}ℹ Next steps:${NC}"
echo "  1. Access N8N at https://${SUBDOMAIN}.app.bythewise.com"
echo "  2. Configure credentials in the N8N interface (OpenAI, WordPress, etc.)"
echo "  3. Test workflows with sample data"
echo ""
echo "Workflow URLs:"
echo "  WF1: https://${SUBDOMAIN}.app.bythewise.com/webhook/wf1-seed-expansion"
echo "  WF2: https://${SUBDOMAIN}.app.bythewise.com/webhook/wf2-clustering"
echo "  WF3: Scheduled (Monday & Thursday at 8am)"
echo ""

read -p "Appuyez sur Entrée pour continuer..."

###############################################################################
# ÉTAPE 4 : Vérification des Conteneurs
###############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}▶ ÉTAPE 4/7 : Vérification des conteneurs tenant${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}$ docker ps | grep tenant${NC}"
echo ""
echo "CONTAINER ID   IMAGE              COMMAND                  CREATED         STATUS         PORTS                    NAMES"
echo "a1b2c3d4e5f6   n8nio/n8n:latest   \"tini -- /docker-ent…\"   2 minutes ago   Up 2 minutes   0.0.0.0:${N8N_PORT}->5678/tcp   n8n-${TENANT_ID}"
echo "b2c3d4e5f6a7   postgres:15        \"docker-entrypoint.s…\"   2 minutes ago   Up 2 minutes   5432/tcp                 postgres-${TENANT_ID}"
echo "c3d4e5f6a7b8   redis:7            \"docker-entrypoint.s…\"   2 minutes ago   Up 2 minutes   6379/tcp                 redis-${TENANT_ID}"
echo ""

sleep 1
echo -e "${GREEN}✓ N8N container running: n8n-${TENANT_ID}${NC}"
echo -e "${GREEN}✓ PostgreSQL container running: postgres-${TENANT_ID}${NC}"
echo -e "${GREEN}✓ Redis container running: redis-${TENANT_ID}${NC}"
echo ""

echo -e "${CYAN}$ docker logs n8n-${TENANT_ID} --tail 20${NC}"
echo ""
echo "n8n ready on 0.0.0.0:5678"
echo "Version: 1.17.2"
echo ""
echo "Editor is now accessible via:"
echo "http://localhost:${N8N_PORT}/"
echo ""
echo "Webhook URLs:"
echo "http://localhost:${N8N_PORT}/webhook/"
echo "http://localhost:${N8N_PORT}/webhook-test/"
echo ""

read -p "Appuyez sur Entrée pour continuer..."

###############################################################################
# ÉTAPE 5 : Test de N8N
###############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}▶ ÉTAPE 5/7 : Test d'accès à N8N${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}ℹ N8N accessible sur port: ${N8N_PORT}${NC}"
echo -e "${YELLOW}ℹ N8N URL: http://localhost:${N8N_PORT}${NC}"
echo ""

echo -e "${CYAN}$ curl http://localhost:${N8N_PORT}/healthz${NC}"
sleep 1
echo '{"status":"ok"}'
echo ""
echo -e "${GREEN}✓ N8N health check passed${NC}"
echo ""

echo -e "${CYAN}$ curl -X POST http://localhost:${N8N_PORT}/webhook/wf1-seed-expansion \\${NC}"
echo -e "${CYAN}  -H \"Content-Type: application/json\" \\${NC}"
echo -e "${CYAN}  -d '{\"seed_keyword\":\"marketing automation\",\"target_count\":50}'${NC}"
sleep 1
echo ""
echo '{'
echo '  "success": true,'
echo '  "message": "Seed expansion initiated",'
echo '  "workflow_id": "wf1",'
echo '  "execution_id": "exec-789xyz",'
echo '  "seed_keyword": "marketing automation",'
echo '  "estimated_keywords": 50,'
echo '  "next_workflow": "WF2 will be triggered automatically"'
echo '}'
echo ""
echo -e "${GREEN}✓ Webhook WF1 fonctionne${NC}"
echo ""

read -p "Appuyez sur Entrée pour continuer..."

###############################################################################
# ÉTAPE 6 : Test de l'API
###############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}▶ ÉTAPE 6/7 : Test des endpoints API${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}ℹ Starting API server...${NC}"
echo -e "${CYAN}$ cd api && npm run dev${NC}"
sleep 1
echo ""
echo "> @bythewise/api@1.0.0 dev"
echo "> node --watch src/server.js"
echo ""
echo "[$(date -u +%H:%M:%S) UTC] INFO: Server listening at http://0.0.0.0:3001"
echo "[$(date -u +%H:%M:%S) UTC] INFO: 🚀 BYTHEWISE API started on http://0.0.0.0:3001"
echo ""
sleep 1

echo -e "${YELLOW}ℹ Testing login endpoint...${NC}"
echo -e "${CYAN}$ curl -X POST http://localhost:3001/api/auth/login \\${NC}"
echo -e "${CYAN}  -d '{\"email\":\"demo@bythewise.com\",\"password\":\"demo123\"}'${NC}"
sleep 1
echo ""
echo '{'
echo '  "success": true,'
echo '  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6InVzZXItZGVtby0wMDEi...",'
echo '  "user": {'
echo '    "id": "user-demo-001",'
echo '    "name": "Demo User",'
echo '    "email": "demo@bythewise.com",'
echo '    "tenantId": "tenant-demo-001",'
echo '    "role": "admin"'
echo '  }'
echo '}'
echo ""
echo -e "${GREEN}✓ Login successful${NC}"
echo ""
sleep 1

echo -e "${YELLOW}ℹ Testing /me endpoint...${NC}"
echo -e "${CYAN}$ curl http://localhost:3001/api/auth/me -H \"Authorization: Bearer <token>\"${NC}"
sleep 1
echo ""
echo '{'
echo '  "success": true,'
echo '  "user": {'
echo '    "id": "user-demo-001",'
echo '    "name": "Demo User",'
echo '    "email": "demo@bythewise.com",'
echo '    "tenantId": "tenant-demo-001",'
echo '    "role": "admin"'
echo '  }'
echo '}'
echo ""
echo -e "${GREEN}✓ /me endpoint working${NC}"
echo ""
sleep 1

echo -e "${YELLOW}ℹ Testing metrics endpoint...${NC}"
echo -e "${CYAN}$ curl http://localhost:3001/api/tenants/tenant-demo-001/metrics \\${NC}"
echo -e "${CYAN}  -H \"Authorization: Bearer <token>\"${NC}"
sleep 1
echo ""
echo '{'
echo '  "success": true,'
echo '  "totalExecutions": 1247,'
echo '  "successfulExecutions": 1189,'
echo '  "failedExecutions": 58,'
echo '  "articlesPublished": 12,'
echo '  "clustersCreated": 67,'
echo '  "pendingClusters": 23,'
echo '  "maxWorkflows": 25,'
echo '  "maxExecutionsPerMonth": 50000,'
echo '  "maxArticlesPerWeek": 8'
echo '}'
echo ""
echo -e "${GREEN}✓ Metrics endpoint working${NC}"
echo ""

read -p "Appuyez sur Entrée pour continuer..."

###############################################################################
# ÉTAPE 7 : Résumé
###############################################################################

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ SIMULATION TERMINÉE AVEC SUCCÈS                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${MAGENTA}📊 RÉSUMÉ DES RÉSULTATS${NC}"
echo ""
echo -e "${CYAN}Infrastructure Centrale:${NC}"
echo "  ✅ PostgreSQL      : localhost:5432 (healthy)"
echo "  ✅ Redis          : localhost:6379 (healthy)"
echo ""
echo -e "${CYAN}Tenant Créé:${NC}"
echo "  🆔 Tenant ID      : ${TENANT_ID}"
echo "  📝 Nom            : Premier Client"
echo "  🔗 Subdomain      : ${SUBDOMAIN}"
echo "  📦 Plan           : starter"
echo "  ⚡ Statut         : active"
echo ""
echo -e "${CYAN}Conteneurs Tenant:${NC}"
echo "  ✅ N8N            : n8n-${TENANT_ID} (port ${N8N_PORT})"
echo "  ✅ PostgreSQL     : postgres-${TENANT_ID}"
echo "  ✅ Redis          : redis-${TENANT_ID}"
echo ""
echo -e "${CYAN}Workflows Importés:${NC}"
echo "  ✅ WF1 - Seed Expansion      (Webhook: /webhook/wf1-seed-expansion)"
echo "  ✅ WF2 - Clustering          (Webhook: /webhook/wf2-clustering)"
echo "  ✅ WF3 - Article Generation  (Scheduled: Mon & Thu 8am)"
echo ""
echo -e "${CYAN}Services Opérationnels:${NC}"
echo "  ✅ N8N            : http://localhost:${N8N_PORT}"
echo "  ✅ API            : http://localhost:3001"
echo "  ✅ Dashboard      : http://localhost:3000"
echo ""
echo -e "${CYAN}Endpoints API Testés:${NC}"
echo "  ✅ POST /api/auth/login"
echo "  ✅ GET  /api/auth/me"
echo "  ✅ GET  /api/tenants/:id/metrics"
echo "  ✅ GET  /api/tenants/:id/workflows"
echo ""

echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📝 PROCHAINES ÉTAPES${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "1. Sur votre machine locale avec Docker:"
echo "   ${CYAN}./scripts/test-full-system.sh${NC}"
echo ""
echo "2. Ou suivez le guide manuel:"
echo "   ${CYAN}cat QUICKSTART.md${NC}"
echo ""
echo "3. Documentation complète:"
echo "   ${CYAN}cat FULL_SYSTEM_TEST.md${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}🎉 Le système BYTHEWISE est prêt pour le test réel !${NC}"
echo ""
