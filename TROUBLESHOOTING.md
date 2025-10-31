# 🔧 BYTHEWISE SaaS - Guide de Dépannage

## 🚨 Problème : `create-tenant.sh` se bloque après "Generating tenant configuration..."

### Causes Possibles

1. **Base de données non initialisée**
   - La base `bythewise_central` n'existe pas
   - Les tables ne sont pas créées

2. **Credentials incorrects**
   - Le username/password dans `.env` ne correspond pas au conteneur PostgreSQL
   - La base de données utilise des credentials différents

3. **Connexion impossible**
   - PostgreSQL n'est pas accessible depuis Node.js
   - Le port n'est pas exposé correctement

4. **Docker socket inaccessible**
   - Le script ne peut pas créer de nouveaux conteneurs
   - Permissions Docker manquantes

---

## ✅ Solution Rapide (Recommandée)

### Étape 1 : Test de connexion rapide

```bash
./scripts/test-connection.sh
```

**Si ça passe :** Votre configuration est bonne, passez au script debug
**Si ça échoue :** Passez à l'étape 2

### Étape 2 : Diagnostic et correction automatique

```bash
./scripts/diagnose-and-fix.sh
```

Ce script va :
- ✅ Vérifier que PostgreSQL répond
- ✅ Tester les credentials
- ✅ Créer la base de données si nécessaire
- ✅ Initialiser le schéma (5 tables)
- ✅ Tester la connexion Node.js
- ✅ Vérifier Redis

### Étape 3 : Création du tenant en mode debug

```bash
./scripts/create-tenant-debug.sh "Premier Client" starter
```

Le script debug affiche :
- Tous les logs intermédiaires
- Les valeurs des variables
- Les erreurs détaillées
- Un timeout de 60 secondes

---

## 🔍 Diagnostic Manuel

### 1. Vérifier que PostgreSQL fonctionne

```bash
# Lister les conteneurs
docker ps

# Devrait afficher quelque chose comme:
# postgres-temp ou redis-simple
```

**Si aucun conteneur PostgreSQL :**
```bash
docker run -d \
  --name postgres-temp \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=changeme \
  -p 5432:5432 \
  postgres:15-alpine
```

### 2. Vérifier la base de données

```bash
# Remplacer postgres-temp par le nom de votre conteneur
docker exec -it postgres-temp psql -U admin -l
```

**Si `bythewise_central` n'existe pas :**
```bash
docker exec -it postgres-temp psql -U admin -c "CREATE DATABASE bythewise_central;"
```

### 3. Vérifier les tables

```bash
docker exec -it postgres-temp psql -U admin -d bythewise_central -c "\dt"
```

**Si aucune table :**
```bash
# Copier et exécuter le schéma
docker cp api/src/config/schema.sql postgres-temp:/tmp/schema.sql
docker exec -it postgres-temp psql -U admin -d bythewise_central -f /tmp/schema.sql
```

### 4. Tester la connexion depuis Node.js

```bash
cd api

# Créer un script de test
cat > /tmp/test-db.js << 'EOF'
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config({ path: '.env' });

const { Pool } = pg;
const pool = new Pool({
    host: process.env.POSTGRES_HOST || 'localhost',
    port: process.env.POSTGRES_PORT || 5432,
    database: process.env.POSTGRES_DB || 'bythewise_central',
    user: process.env.POSTGRES_USER || 'admin',
    password: process.env.POSTGRES_PASSWORD || 'changeme',
});

async function test() {
    try {
        const client = await pool.connect();
        console.log('✓ Connexion réussie');
        const result = await client.query('SELECT NOW()');
        console.log('✓ Query OK:', result.rows[0]);
        client.release();
        await pool.end();
        process.exit(0);
    } catch (error) {
        console.error('✗ Erreur:', error.message);
        process.exit(1);
    }
}

test();
EOF

node /tmp/test-db.js
```

### 5. Vérifier le fichier .env

```bash
cat api/.env
```

**Vérifiez que ces valeurs correspondent à votre configuration :**
```ini
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=bythewise_central
POSTGRES_USER=admin         # ← Doit correspondre à votre conteneur
POSTGRES_PASSWORD=changeme  # ← Doit correspondre à votre conteneur
```

**Si les credentials sont incorrects :**
```bash
# Modifier api/.env avec les bons credentials
nano api/.env

# Ou recréer depuis l'exemple
cp api/.env.example api/.env
# Puis éditer avec vos valeurs
```

---

## 🐛 Erreurs Courantes

### Erreur: "Cannot connect to database"

**Cause :** Credentials incorrects ou base de données inexistante

**Solution :**
```bash
# 1. Vérifier les credentials du conteneur
docker exec postgres-temp env | grep POSTGRES

# 2. Mettre à jour api/.env avec les bonnes valeurs

# 3. Tester la connexion
docker exec postgres-temp psql -U <USER> -d bythewise_central -c "SELECT 1"
```

### Erreur: "Database does not exist"

**Solution :**
```bash
docker exec postgres-temp psql -U admin -c "CREATE DATABASE bythewise_central;"
```

### Erreur: "No tables found"

**Solution :**
```bash
./scripts/diagnose-and-fix.sh
```

Ou manuellement :
```bash
docker cp api/src/config/schema.sql postgres-temp:/tmp/schema.sql
docker exec postgres-temp psql -U admin -d bythewise_central -f /tmp/schema.sql
```

### Erreur: "Error: listen EADDRINUSE :::3001"

**Cause :** Le port 3001 est déjà utilisé

**Solution :**
```bash
# Trouver le processus
lsof -i :3001

# Tuer le processus
kill -9 <PID>

# Ou changer le port dans api/.env
PORT=3002
```

### Erreur: "Docker socket not accessible"

**Cause :** Permissions Docker manquantes

**Solution :**
```bash
# Ajouter votre user au groupe docker
sudo usermod -aG docker $USER

# Se déconnecter et reconnecter, ou
newgrp docker
```

### Script bloque sans message

**Cause :** Connexion qui hang indéfiniment

**Solution :** Utiliser le script debug qui a un timeout de 60s
```bash
./scripts/create-tenant-debug.sh "Test" starter
```

---

## 📊 Ordre de Résolution

```
1. Test rapide
   ↓ ✓
2. Diagnose-and-fix
   ↓ ✓
3. Create-tenant-debug
   ↓ ✓
4. Tenant créé avec succès!
```

Si le problème persiste après toutes ces étapes :

```bash
# Logs détaillés
./scripts/create-tenant-debug.sh "Test" starter > /tmp/debug.log 2>&1

# Partager le fichier /tmp/debug.log pour analyse
cat /tmp/debug.log
```

---

## 🔄 Reset Complet

Si tout est cassé et vous voulez repartir de zéro :

```bash
# 1. Arrêter tous les conteneurs BYTHEWISE
docker stop $(docker ps -q --filter name=tenant)
docker stop postgres-temp redis-simple

# 2. Supprimer les conteneurs
docker rm $(docker ps -aq --filter name=tenant)
docker rm postgres-temp redis-simple

# 3. Supprimer les volumes (ATTENTION: perte de données!)
docker volume rm $(docker volume ls -q | grep bythewise)

# 4. Recréer l'infrastructure
docker run -d \
  --name postgres-temp \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=changeme \
  -e POSTGRES_DB=bythewise_central \
  -p 5432:5432 \
  postgres:15-alpine

docker run -d \
  --name redis-simple \
  -p 6379:6379 \
  redis:7-alpine

# 5. Attendre 10 secondes
sleep 10

# 6. Initialiser
./scripts/diagnose-and-fix.sh

# 7. Créer un tenant
./scripts/create-tenant-debug.sh "Premier Client" starter
```

---

## ✅ Vérification Finale

Une fois le tenant créé, vérifiez :

```bash
# 1. Conteneurs tenant
docker ps | grep tenant

# Devrait afficher:
# n8n-tenant-xxx
# postgres-tenant-xxx
# redis-tenant-xxx

# 2. Logs N8N
docker logs n8n-tenant-xxx

# Devrait afficher:
# n8n ready on 0.0.0.0:5678

# 3. Accès N8N
curl http://localhost:5678/healthz

# Devrait retourner:
# {"status":"ok"}
```

---

## 📞 Support

Si vous avez toujours des problèmes :

1. Lancez le script debug et capturez la sortie
2. Vérifiez les logs avec `docker logs <container>`
3. Vérifiez la configuration dans `api/.env`
4. Consultez FULL_SYSTEM_TEST.md pour plus de détails

---

**🎯 Dans 99% des cas, `./scripts/diagnose-and-fix.sh` résout le problème !**
