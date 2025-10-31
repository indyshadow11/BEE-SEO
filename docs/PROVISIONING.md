# BYTHEWISE SaaS - Provisioning Multi-Tenant

Ce document explique comment utiliser le système de provisioning multi-tenant.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Prérequis](#prérequis)
- [Initialisation](#initialisation)
- [Création d'un tenant](#création-dun-tenant)
- [Gestion des tenants](#gestion-des-tenants)
- [Architecture](#architecture)
- [Dépannage](#dépannage)

## Vue d'ensemble

Le système de provisioning BYTHEWISE permet de créer automatiquement des instances N8N isolées pour chaque client, avec leur propre base de données PostgreSQL et instance Redis.

Chaque tenant obtient :
- Une instance N8N dédiée
- Une base de données PostgreSQL isolée
- Une instance Redis pour les queues
- Un réseau Docker isolé
- Un sous-domaine unique (ex: `client-name.app.bythewise.com`)

## Prérequis

Avant de commencer, assurez-vous d'avoir :

- Docker et Docker Compose installés
- Node.js 20+ installé
- PostgreSQL accessible (pour la base centrale)
- Accès root/sudo (pour Docker)

## Initialisation

### 1. Installation des dépendances

```bash
cd api
npm install
```

### 2. Configuration de l'environnement

Copiez le fichier `.env.example` et configurez les variables :

```bash
cp .env.example .env
```

Éditez `.env` avec vos valeurs :

```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=bythewise_central
POSTGRES_USER=admin
POSTGRES_PASSWORD=votre-mot-de-passe-sécurisé
```

### 3. Initialiser la base de données centrale

```bash
# Démarrer PostgreSQL (via Docker Compose)
make dev

# Initialiser le schéma de la base de données
cd api
npm run db:init
```

Cette commande créera automatiquement :
- La table `tenants`
- La table `users`
- La table `workflow_executions`
- La table `billing`
- La table `audit_logs`
- Les index et triggers nécessaires

### 4. Créer le réseau Docker public

```bash
docker network create public
```

## Création d'un tenant

### Méthode 1 : Script Bash

Le script `create-tenant.sh` est la méthode recommandée :

```bash
./scripts/create-tenant.sh "Nom du Client" starter
```

**Arguments :**
- `Nom du Client` : Nom du client (obligatoire)
- `plan` : starter, pro, business, ou enterprise (par défaut: starter)

**Exemples :**

```bash
# Créer un tenant starter
./scripts/create-tenant.sh "Test Client" starter

# Créer un tenant pro
./scripts/create-tenant.sh "Acme Corp" pro

# Créer un tenant business
./scripts/create-tenant.sh "Big Company" business
```

### Méthode 2 : CLI Node.js

Vous pouvez aussi utiliser le CLI Node.js directement :

```bash
cd api
npm run cli create-tenant "Nom du Client" starter
```

## Gestion des tenants

### Lister tous les tenants

```bash
cd api
npm run cli list-tenants
```

### Obtenir le statut d'un tenant

```bash
cd api
npm run cli status-tenant <tenant-id>
```

Affiche :
- Informations du tenant
- État des conteneurs
- Métriques d'utilisation (30 derniers jours)
- Limites du plan

### Supprimer un tenant

```bash
cd api
npm run cli delete-tenant <tenant-id>
```

⚠️ **Attention** : Cette opération :
- Arrête tous les conteneurs du tenant
- Supprime les volumes Docker (données N8N, PostgreSQL, Redis)
- Marque le tenant comme "deleted" dans la base centrale
- Est irréversible

## Architecture

### Structure des fichiers

```
docker/
├── compose/
│   └── tenant-template.yml      # Template Docker Compose pour tenants
├── tenants/
│   └── docker-compose-tenant-{id}.yml  # Fichiers générés pour chaque tenant

api/
├── src/
│   ├── config/
│   │   ├── database.js          # Connexion PostgreSQL centrale
│   │   └── schema.sql           # Schéma de la base centrale
│   ├── services/
│   │   └── orchestrator.js      # Logique de provisioning
│   └── cli.js                   # Interface CLI
```

### Isolation des tenants

Chaque tenant est isolé via :

1. **Réseau Docker isolé** : `tenant_{id}`
   - Subnet unique : `172.X.0.0/24`
   - Mode `internal` : pas d'accès Internet direct

2. **Conteneurs dédiés** :
   - N8N : `n8n-tenant-{id}`
   - PostgreSQL : `postgres-tenant-{id}`
   - Redis : `redis-tenant-{id}`

3. **Volumes séparés** :
   - `n8n_data_{id}`
   - `postgres_data_{id}`
   - `redis_data_{id}`

4. **Credentials uniques** :
   - Mot de passe PostgreSQL généré aléatoirement
   - Mot de passe Redis généré aléatoirement

### Plans et limites

| Plan | Workflows | Exécutions/mois | Articles/semaine | Prix |
|------|-----------|-----------------|------------------|------|
| **Starter** | 5 | 10,000 | 2 | 49€ |
| **Pro** | 25 | 50,000 | 8 | 149€ |
| **Business** | Illimité | 250,000 | 20 | 499€ |
| **Enterprise** | Illimité | Illimité | Illimité | Sur mesure |

## Dépannage

### Erreur : "Subdomain already exists"

Le sous-domaine est généré automatiquement à partir du nom du client. Si deux clients ont le même nom, ajoutez un suffixe unique :

```bash
./scripts/create-tenant.sh "Client A - Site 1" starter
./scripts/create-tenant.sh "Client A - Site 2" starter
```

### Erreur : "Docker network create failed"

Le réseau public n'existe pas. Créez-le :

```bash
docker network create public
```

### Conteneurs ne démarrent pas

Vérifiez les logs :

```bash
# Logs N8N
docker logs n8n-tenant-{id}

# Logs PostgreSQL
docker logs postgres-tenant-{id}

# Logs Redis
docker logs redis-tenant-{id}
```

### Base de données PostgreSQL inaccessible

Vérifiez que PostgreSQL est démarré :

```bash
docker ps | grep postgres

# Démarrer si nécessaire
make dev
```

Testez la connexion :

```bash
docker exec -it bythewise-postgres psql -U admin -d bythewise_central
```

### Vérifier l'état d'un tenant

```bash
cd api
npm run cli status-tenant <tenant-id>
```

### Recréer un tenant

Si un tenant est en état d'erreur, supprimez-le et recréez-le :

```bash
# 1. Supprimer
cd api
npm run cli delete-tenant <tenant-id>

# 2. Recréer
./scripts/create-tenant.sh "Nom du Client" starter
```

## API JavaScript

Vous pouvez aussi utiliser l'orchestrator directement dans votre code :

```javascript
import { createTenant, deleteTenant, getTenantStatus, listTenants } from './api/src/services/orchestrator.js';

// Créer un tenant
const tenant = await createTenant('Mon Client', 'pro');
console.log('Tenant créé:', tenant.id);

// Obtenir le statut
const status = await getTenantStatus(tenant.id);
console.log('Statut:', status.status);
console.log('URL N8N:', status.n8n_url);

// Lister les tenants
const tenants = await listTenants({ status: 'active' });
console.log('Tenants actifs:', tenants.length);

// Supprimer un tenant
await deleteTenant(tenant.id);
```

## Prochaines étapes

Après avoir créé un tenant :

1. **Configurer le DNS** : Pointez `{subdomain}.app.bythewise.com` vers votre serveur
2. **Importer les workflows** : Uploadez WF1, WF2, WF3 dans N8N
3. **Configurer les credentials** : API keys (OpenAI, WordPress, etc.)
4. **Tester l'exécution** : Lancer un workflow de test

---

Pour plus d'informations, consultez le README principal du projet.
