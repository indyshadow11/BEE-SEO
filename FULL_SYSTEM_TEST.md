# 🧪 Guide de Test Complet - BYTHEWISE SaaS avec Docker & N8N

Ce guide vous permet de tester le système complet avec un vrai tenant N8N isolé.

## ⚠️ Prérequis

- Docker et Docker Compose installés
- Node.js 18+ installé
- Ports disponibles : 3000, 3001, 5432, 6379, 80, 443

## 📋 Étapes de Test

### 1️⃣ Démarrer l'Infrastructure Docker

```bash
# Retour au répertoire du projet
cd /chemin/vers/BEE-SEO

# Créer le fichier .env si nécessaire
cp api/.env.example api/.env

# Démarrer PostgreSQL central
docker compose up -d postgres

# Attendre que PostgreSQL soit prêt (environ 10 secondes)
sleep 10

# Vérifier que PostgreSQL fonctionne
docker compose ps postgres

# Démarrer Redis
docker compose up -d redis

# Attendre que Redis soit prêt
sleep 5

# Vérifier les deux conteneurs
docker compose ps
```

**Résultat attendu :**
```
NAME                   STATUS         PORTS
bythewise-postgres     Up (healthy)   0.0.0.0:5432->5432/tcp
bythewise-redis        Up (healthy)   0.0.0.0:6379->6379/tcp
```

### 2️⃣ Initialiser la Base de Données Centrale

```bash
# Se déplacer dans le dossier API
cd api

# Installer les dépendances si ce n'est pas fait
npm install

# Initialiser le schéma de la base de données
npm run db:init
```

**Résultat attendu :**
```
✓ Connected to PostgreSQL
✓ Running schema migrations...
✓ Created extension: uuid-generate-v4
✓ Created table: tenants
✓ Created table: users
✓ Created table: workflow_executions
✓ Created table: billing
✓ Created table: audit_logs
✓ Created triggers and policies
✓ Database initialized successfully
```

**Vérification manuelle (optionnelle) :**
```bash
docker exec -it bythewise-postgres psql -U admin -d bythewise_central -c "\dt"
```

Vous devriez voir : `tenants`, `users`, `workflow_executions`, `billing`, `audit_logs`

### 3️⃣ Créer un Tenant de Test Réel

```bash
# Retour à la racine du projet
cd ..

# Rendre le script exécutable
chmod +x scripts/create-tenant.sh
chmod +x scripts/import-workflows.sh

# Créer le premier tenant
./scripts/create-tenant.sh "Premier Client" starter
```

**Résultat attendu :**
```
═══════════════════════════════════════════════════════════
  BYTHEWISE SaaS - Tenant Provisioning
═══════════════════════════════════════════════════════════

ℹ Client Name: Premier Client
ℹ Plan: starter

▶ Checking dependencies...
✓ Docker found
✓ docker-compose found
✓ Node.js found (v22.x.x)
✓ Public network exists

▶ Generating tenant configuration...
Initializing database...
Creating tenant...

============================================================
TENANT CREATED SUCCESSFULLY
============================================================
ID: tenant-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Name: Premier Client
Subdomain: premier-client
Plan: starter
Status: active
N8N URL: http://premier-client.n8n.local:5678
Created: 2025-10-31T...
============================================================

Containers:
  N8N: n8n-tenant-xxxxxxxx
  PostgreSQL: postgres-tenant-xxxxxxxx
  Redis: redis-tenant-xxxxxxxx
============================================================

TENANT_ID=tenant-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

✓ Tenant provisioning completed!

▶ Importing workflows to N8N...
⏳ Waiting for N8N to be ready... (attempt 1/30)
✓ N8N is healthy and ready!
✓ Imported WF1 - Seed Expansion (ID: 1)
✓ Imported WF2 - Clustering (ID: 2)
✓ Imported WF3 - Article Generation (ID: 3)
✓ Workflows imported successfully!

ℹ Next steps:
  1. Access N8N at https://premier-client.app.bythewise.com
  2. Configure credentials in the N8N interface (OpenAI, WordPress, etc.)
  3. Test workflows with sample data

Workflow URLs:
  WF1: https://premier-client.app.bythewise.com/webhook/wf1-seed-expansion
  WF2: https://premier-client.app.bythewise.com/webhook/wf2-clustering
  WF3: Scheduled (Monday & Thursday at 8am)
```

**⚠️ Important :** Notez le `TENANT_ID` retourné !

### 4️⃣ Vérifier que N8N Fonctionne

```bash
# Lister tous les conteneurs tenant
docker ps | grep tenant

# Afficher les logs N8N du tenant (remplacer XXXXXXXX par votre ID)
docker logs n8n-tenant-XXXXXXXX --tail 50

# Vérifier le statut complet
docker inspect n8n-tenant-XXXXXXXX --format='{{.State.Status}}'
```

**Résultat attendu pour `docker ps | grep tenant` :**
```
CONTAINER ID   IMAGE              STATUS         PORTS                    NAMES
abc123def456   n8nio/n8n:latest   Up 2 minutes   0.0.0.0:5678->5678/tcp   n8n-tenant-XXXXXXXX
def789ghi012   postgres:15        Up 2 minutes   5432/tcp                 postgres-tenant-XXXXXXXX
ghi345jkl678   redis:7            Up 2 minutes   6379/tcp                 redis-tenant-XXXXXXXX
```

**Résultat attendu pour les logs N8N :**
```
n8n ready on 0.0.0.0:5678
Version: 1.x.x
Webhook URL: http://premier-client.n8n.local:5678/webhook/
Editor is now accessible via: http://premier-client.n8n.local:5678/
```

**Accéder à l'interface N8N :**
```bash
# Trouver le port mappé
docker port n8n-tenant-XXXXXXXX 5678

# Si mappé sur port 5678, ouvrir dans le navigateur :
# http://localhost:5678
```

### 5️⃣ Vérifier les Workflows Importés

Dans l'interface N8N (http://localhost:5678) :

1. **Vérifiez la liste des workflows** :
   - WF1 - Seed Expansion
   - WF2 - Clustering
   - WF3 - Article Generation

2. **Vérifiez les webhooks actifs** :
   - Ouvrir WF1
   - Le nœud Webhook devrait afficher : `http://localhost:5678/webhook/wf1-seed-expansion`

3. **Tester un webhook manuellement** :
   ```bash
   curl -X POST http://localhost:5678/webhook/wf1-seed-expansion \
     -H "Content-Type: application/json" \
     -d '{
       "seed_keyword": "marketing automation",
       "tenant_id": "tenant-XXXXXXXX",
       "target_count": 200
     }'
   ```

### 6️⃣ Tester dans le Dashboard

```bash
# Démarrer l'API (dans un terminal séparé)
cd api
npm run dev
# API sur http://localhost:3001

# Démarrer le Dashboard (dans un autre terminal)
cd dashboard
npm run dev
# Dashboard sur http://localhost:3000
```

**Dans le navigateur :**

1. **Connexion** : http://localhost:3000/login
   - Email: `demo@bythewise.com`
   - Password: `demo123`

2. **Accéder au tenant** :
   - Remplacez l'ID dans l'URL : http://localhost:3000/dashboard?tenant=TENANT_ID
   - Ou modifiez le code pour utiliser votre tenant ID

3. **Vérifier les pages** :
   - Metrics : http://localhost:3000/dashboard
   - Workflows : http://localhost:3000/dashboard/workflows
   - Articles : http://localhost:3000/dashboard/articles

### 7️⃣ Tester l'API avec le Tenant Réel

```bash
# 1. Login et obtenir le token
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@bythewise.com","password":"demo123"}' | jq -r .token)

echo "Token: $TOKEN"

# 2. Récupérer les infos du tenant
curl -s -X GET http://localhost:3001/api/tenants/TENANT_ID/status \
  -H "Authorization: Bearer $TOKEN" | jq .

# 3. Lister les workflows du tenant
curl -s -X GET http://localhost:3001/api/tenants/TENANT_ID/workflows \
  -H "Authorization: Bearer $TOKEN" | jq .

# 4. Déclencher WF1 manuellement
curl -s -X POST http://localhost:3001/api/tenants/TENANT_ID/workflows/wf1/execute \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "seed_keyword": "seo automation",
    "target_count": 50
  }' | jq .
```

## 🧹 Nettoyage Après Test

```bash
# Supprimer le tenant (containers + network)
npm run cli delete-tenant TENANT_ID

# Arrêter l'infrastructure centrale
docker compose down

# Supprimer complètement (avec volumes)
docker compose down -v

# Supprimer les réseaux tenant orphelins
docker network prune -f
```

## 🐛 Dépannage

### PostgreSQL ne démarre pas
```bash
docker compose logs postgres
docker compose restart postgres
```

### N8N n'est pas accessible
```bash
# Vérifier les logs
docker logs n8n-tenant-XXXXXXXX

# Vérifier le port mapping
docker port n8n-tenant-XXXXXXXX

# Redémarrer le conteneur
docker restart n8n-tenant-XXXXXXXX
```

### La base de données n'est pas initialisée
```bash
# Se connecter à PostgreSQL
docker exec -it bythewise-postgres psql -U admin -d bythewise_central

# Vérifier les tables
\dt

# Si vides, réinitialiser
cd api
npm run db:init
```

### Les workflows ne sont pas importés
```bash
# Réimporter manuellement
./scripts/import-workflows.sh TENANT_ID

# Vérifier les logs d'import
cat /tmp/n8n-import-TENANT_ID.log
```

## 📊 Commandes de Monitoring

```bash
# Voir tous les conteneurs tenant
docker ps -a | grep tenant

# Monitorer les ressources
docker stats $(docker ps -q --filter name=tenant)

# Inspecter le réseau tenant
docker network inspect tenant-XXXXXXXX

# Voir les logs en temps réel
docker logs -f n8n-tenant-XXXXXXXX
```

## ✅ Checklist de Validation

- [ ] PostgreSQL central démarré et healthy
- [ ] Redis central démarré et healthy
- [ ] Base de données initialisée avec toutes les tables
- [ ] Tenant créé avec ID unique
- [ ] 3 conteneurs tenant lancés (N8N + PostgreSQL + Redis)
- [ ] N8N accessible sur le port 5678
- [ ] 3 workflows importés dans N8N
- [ ] Webhook WF1 répond aux requêtes cURL
- [ ] API retourne les infos du tenant
- [ ] Dashboard affiche les workflows du tenant

## 🎯 Résultats Attendus

À la fin de ce test, vous devriez avoir :

1. **Infrastructure centrale** : PostgreSQL + Redis opérationnels
2. **Un tenant isolé** avec ses propres conteneurs N8N, PostgreSQL, Redis
3. **3 workflows fonctionnels** dans N8N avec webhooks configurés
4. **API opérationnelle** retournant les données du tenant
5. **Dashboard fonctionnel** affichant les métriques et workflows

## 🚀 Prochaines Étapes

Une fois le test validé :

1. **Créer un second tenant** pour tester l'isolation multi-tenant
2. **Configurer les credentials N8N** (OpenAI API, WordPress, etc.)
3. **Tester un workflow complet** end-to-end
4. **Configurer le DNS** pour accéder via subdomains
5. **Déployer en production** avec Caddy pour SSL automatique
