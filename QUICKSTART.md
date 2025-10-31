# 🚀 BYTHEWISE SaaS - Quick Start Guide

Ce guide vous permet de tester rapidement le système complet en **5 minutes**.

## ⚡ Test Automatique (Recommandé)

Sur votre machine locale avec Docker installé :

```bash
# 1. Cloner le projet (si ce n'est pas déjà fait)
git clone <repository-url>
cd BEE-SEO

# 2. Configurer l'environnement
cp api/.env.example api/.env

# 3. Lancer le test automatique complet
chmod +x scripts/test-full-system.sh
./scripts/test-full-system.sh
```

Ce script va automatiquement :
- ✅ Démarrer PostgreSQL et Redis
- ✅ Initialiser la base de données
- ✅ Créer un tenant de test avec N8N
- ✅ Importer les 3 workflows
- ✅ Tester tous les endpoints API
- ✅ Afficher les URLs d'accès

**Durée estimée : 2-3 minutes**

## 📋 Test Manuel (Étape par Étape)

Si vous préférez comprendre chaque étape :

### Étape 1 : Infrastructure

```bash
# Démarrer PostgreSQL et Redis
docker compose up -d postgres redis

# Attendre 10 secondes
sleep 10

# Vérifier
docker compose ps
```

### Étape 2 : Base de Données

```bash
cd api
npm install
npm run db:init
cd ..
```

### Étape 3 : Créer un Tenant

```bash
chmod +x scripts/create-tenant.sh scripts/import-workflows.sh
./scripts/create-tenant.sh "Mon Premier Client" starter
```

**Notez le TENANT_ID affiché !**

### Étape 4 : Vérifier N8N

```bash
# Voir les conteneurs
docker ps | grep tenant

# Voir les logs N8N
docker logs $(docker ps -q --filter name=n8n-tenant-) --tail 50

# Trouver le port N8N
docker port $(docker ps -q --filter name=n8n-tenant-) 5678
```

Ouvrez http://localhost:5678 dans votre navigateur.

### Étape 5 : Tester l'API

```bash
# Démarrer l'API
cd api
npm run dev
```

Dans un autre terminal :

```bash
# Login
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@bythewise.com","password":"demo123"}' | jq .

# Obtenir le token et tester
TOKEN="<votre-token>"
curl http://localhost:3001/api/auth/me \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### Étape 6 : Dashboard

```bash
cd dashboard
npm run dev
```

Ouvrez http://localhost:3000 et connectez-vous avec :
- Email: `demo@bythewise.com`
- Password: `demo123`

## 🎯 Résultats Attendus

Après le test, vous devriez avoir :

| Service | URL | État |
|---------|-----|------|
| PostgreSQL Central | localhost:5432 | ✅ Running |
| Redis Central | localhost:6379 | ✅ Running |
| N8N (Tenant) | localhost:5678 | ✅ Running |
| API Backend | localhost:3001 | ✅ Running |
| Dashboard | localhost:3000 | ✅ Running |

**Workflows dans N8N :**
- ✅ WF1 - Seed Expansion (Webhook)
- ✅ WF2 - Clustering (Webhook)
- ✅ WF3 - Article Generation (Scheduled)

## 🧪 Tests Rapides

### Test Webhook WF1

```bash
# Trouver le port N8N
N8N_PORT=$(docker port $(docker ps -q --filter name=n8n-tenant-) 5678 | cut -d: -f2)

# Envoyer une requête test
curl -X POST http://localhost:$N8N_PORT/webhook/wf1-seed-expansion \
  -H "Content-Type: application/json" \
  -d '{
    "seed_keyword": "marketing automation",
    "tenant_id": "test",
    "target_count": 50
  }'
```

### Test API Complète

```bash
# Script de test rapide
cat > /tmp/test-api.sh << 'EOF'
#!/bin/bash
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@bythewise.com","password":"demo123"}' | jq -r .token)

echo "✓ Login successful"
echo ""

curl -s http://localhost:3001/api/auth/me \
  -H "Authorization: Bearer $TOKEN" | jq .

echo ""
echo "✓ /me endpoint working"

curl -s http://localhost:3001/api/tenants/tenant-demo-001/metrics \
  -H "Authorization: Bearer $TOKEN" | jq .

echo ""
echo "✓ Metrics endpoint working"
EOF

chmod +x /tmp/test-api.sh
/tmp/test-api.sh
```

## 🧹 Nettoyage

### Arrêter tout

```bash
# Arrêter l'API et le Dashboard (Ctrl+C dans chaque terminal)

# Arrêter l'infrastructure
docker compose down

# Supprimer le tenant
cd api
npm run cli delete-tenant <TENANT_ID>
```

### Nettoyage complet

```bash
# Tout supprimer (conteneurs + volumes + réseaux)
docker compose down -v
docker network prune -f
docker volume prune -f
```

## 🐛 Dépannage Rapide

### PostgreSQL ne démarre pas

```bash
docker compose logs postgres
docker compose restart postgres
```

### N8N inaccessible

```bash
# Vérifier les logs
docker logs $(docker ps -q --filter name=n8n-tenant-)

# Redémarrer
docker restart $(docker ps -q --filter name=n8n-tenant-)
```

### API retourne 401

```bash
# Vérifier que .env existe
ls -la api/.env

# Vérifier JWT_SECRET
grep JWT_SECRET api/.env

# Redémarrer l'API
pkill -f "node.*server.js"
cd api && npm run dev
```

### Dashboard ne se connecte pas

```bash
# Vérifier que l'API fonctionne
curl http://localhost:3001/health

# Vérifier CORS
grep CORS_ORIGIN api/.env

# Devrait être : CORS_ORIGIN=http://localhost:3000
```

## 📚 Documentation Complète

Pour plus de détails, consultez :

- **[FULL_SYSTEM_TEST.md](./FULL_SYSTEM_TEST.md)** - Guide de test détaillé avec explications
- **[TESTING.md](./TESTING.md)** - Guide de test API et Dashboard
- **[README.md](./README.md)** - Documentation complète du projet
- **[workflows/README.md](./workflows/README.md)** - Documentation des workflows N8N

## 🆘 Support

En cas de problème :

1. Consultez les logs : `/tmp/bythewise-test-*.log`
2. Vérifiez les conteneurs : `docker compose ps`
3. Vérifiez les logs des services : `docker compose logs <service>`

## ✅ Checklist de Validation

- [ ] PostgreSQL démarré et healthy
- [ ] Redis démarré et healthy
- [ ] Base de données initialisée (5 tables)
- [ ] Tenant créé avec succès
- [ ] 3 conteneurs tenant actifs
- [ ] N8N accessible sur http://localhost:5678
- [ ] 3 workflows visibles dans N8N
- [ ] API répond sur http://localhost:3001
- [ ] Login réussi et token obtenu
- [ ] Dashboard accessible sur http://localhost:3000
- [ ] Connexion dashboard réussie

## 🎉 Prochaines Étapes

Une fois le test réussi :

1. **Configurer les credentials dans N8N** :
   - OpenAI API Key
   - WordPress credentials
   - Base de données PostgreSQL du tenant

2. **Tester un workflow complet** :
   - Envoyer un seed keyword à WF1
   - Vérifier que WF2 est déclenché automatiquement
   - Attendre lundi/jeudi pour WF3 ou modifier le cron

3. **Créer un second tenant** :
   ```bash
   ./scripts/create-tenant.sh "Second Client" pro
   ```

4. **Déployer en production** :
   - Configurer le DNS
   - Configurer SSL avec Caddy
   - Mettre à jour les secrets dans .env
   - Déployer avec `docker compose -f docker-compose.prod.yml up -d`
