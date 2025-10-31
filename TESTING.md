# BYTHEWISE SaaS - Testing Guide

Guide pour tester l'intégration complète du backend API Fastify et du dashboard Next.js.

## Prérequis

- Node.js 20+
- Deux terminaux ouverts

## Démarrage Rapide

### Terminal 1 : Backend API

```bash
# Aller dans le dossier API
cd api

# Installer les dépendances
npm install

# Démarrer le serveur de développement
npm run dev
```

Le serveur API démarre sur **http://localhost:3001**

Vous devriez voir :
```
🚀 BYTHEWISE API started on http://0.0.0.0:3001
```

### Terminal 2 : Dashboard Frontend

```bash
# Aller dans le dossier dashboard
cd dashboard

# Installer les dépendances
npm install

# Démarrer Next.js
npm run dev
```

Le dashboard démarre sur **http://localhost:3000**

## Test de l'Authentification

### 1. Ouvrir le Dashboard

Ouvrir http://localhost:3000 dans votre navigateur.

Vous devriez voir la page d'accueil avec les boutons "Sign In" et "Get Started".

### 2. Se Connecter

Cliquer sur "Sign In" ou aller directement sur http://localhost:3000/login

**Credentials de demo** :
```
Email: demo@bythewise.com
Password: demo123
```

Après connexion, vous devriez être redirigé vers `/dashboard`.

### 3. Vérifier le Token JWT

Ouvrir les Developer Tools (F12) > Application > Local Storage > http://localhost:3000

Vous devriez voir :
- `bythewise_auth_token` : Le token JWT
- `bythewise_user` : Les données de l'utilisateur

## Test des Endpoints API

### Avec cURL

#### 1. Login

```bash
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@bythewise.com",
    "password": "demo123"
  }'
```

Réponse attendue :
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user-demo-001",
    "name": "Demo User",
    "email": "demo@bythewise.com",
    "tenantId": "tenant-demo-001",
    "role": "admin"
  }
}
```

#### 2. Get Current User

```bash
# Remplacez YOUR_TOKEN par le token obtenu lors du login
curl -X GET http://localhost:3001/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### 3. Get Tenant Metrics

```bash
curl -X GET http://localhost:3001/api/tenants/tenant-demo-001/metrics \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Réponse attendue :
```json
{
  "success": true,
  "totalExecutions": 1247,
  "successfulExecutions": 1189,
  "failedExecutions": 58,
  "articlesPublished": 12,
  "clustersCreated": 67,
  "pendingClusters": 23,
  ...
}
```

#### 4. Get Workflows

```bash
curl -X GET http://localhost:3001/api/tenants/tenant-demo-001/workflows \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### 5. Get Articles

```bash
curl -X GET http://localhost:3001/api/tenants/tenant-demo-001/articles \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Avec Postman/Insomnia

1. Créer une nouvelle requête POST vers `http://localhost:3001/api/auth/login`
2. Body > JSON :
   ```json
   {
     "email": "demo@bythewise.com",
     "password": "demo123"
   }
   ```
3. Envoyer et copier le `token` de la réponse
4. Pour les autres requêtes, ajouter le header :
   ```
   Authorization: Bearer {token}
   ```

## Test du Dashboard

### Page Dashboard Principale

URL : http://localhost:3000/dashboard

Vérifier :
- ✅ 4 Metric Cards affichées (Total Executions, Success Rate, Articles, Pending Clusters)
- ✅ Recent Executions timeline (5 exécutions)
- ✅ Quick Actions cards (3 cartes)
- ✅ Navigation bar avec nom d'utilisateur
- ✅ Bouton Logout fonctionnel

### Page Workflows

URL : http://localhost:3000/dashboard/workflows

Vérifier :
- ✅ 3 workflows affichés (WF1, WF2, WF3)
- ✅ Status badges (Active/Inactive)
- ✅ Last execution details
- ✅ Webhook URLs pour WF1 et WF2
- ✅ Schedule info pour WF3
- ✅ Bouton "Execute" sur WF1

### Page Articles

URL : http://localhost:3000/dashboard/articles

Vérifier :
- ✅ Stats cards (Total, This Week, Avg Word Count)
- ✅ Liste de 3 articles
- ✅ Metadata (keywords, word count)
- ✅ Liens "View on WordPress"

## Test de la Protection des Routes

### Test 1 : Accès sans authentification

1. Ouvrir une fenêtre de navigation privée
2. Aller sur http://localhost:3000/dashboard
3. **Attendu** : Redirection automatique vers `/login`

### Test 2 : Token expiré

1. Dans DevTools > Application > Local Storage
2. Supprimer `bythewise_auth_token`
3. Rafraîchir la page
4. **Attendu** : Redirection vers `/login`

### Test 3 : Accès aux pages auth quand connecté

1. Se connecter
2. Essayer d'aller sur http://localhost:3000/login
3. **Attendu** : Redirection vers `/dashboard`

## Test de l'Inscription

### Via le Dashboard

1. Aller sur http://localhost:3000/register
2. Remplir le formulaire :
   - Name : "Test User"
   - Email : "test@example.com"
   - Password : "test123"
   - Confirm Password : "test123"
3. Cocher "I agree to the Terms"
4. Cliquer "Create account"
5. **Attendu** : Redirection vers `/dashboard` et auto-login

### Via API

```bash
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test2@example.com",
    "password": "test123"
  }'
```

## Données Mock Disponibles

Le backend retourne des données mock pour les tests :

### Metrics
- Total Executions : 1247
- Success Rate : 95.3%
- Articles Published : 12
- Pending Clusters : 23

### Workflows
- WF1 - Seed Expansion (webhook)
- WF2 - Clustering (webhook)
- WF3 - Article Generation (scheduled)

### Articles
- 3 articles de démonstration
- Avec keywords, word count, WordPress URLs

### Executions
- 5 dernières exécutions
- Statuses variés (success, error)

## Dépannage

### Erreur CORS

Si vous voyez des erreurs CORS dans la console :

1. Vérifier que l'API est bien sur le port 3001
2. Vérifier que le dashboard est sur le port 3000
3. Redémarrer les deux serveurs

### Erreur "Unauthorized"

1. Vérifier que le token JWT est présent dans localStorage
2. Le token expire après 7 jours
3. Se reconnecter si nécessaire

### API ne répond pas

1. Vérifier que l'API est démarrée : `curl http://localhost:3001/health`
2. Vérifier les logs dans le terminal de l'API
3. Vérifier que le port 3001 n'est pas déjà utilisé

### Dashboard ne se connecte pas à l'API

1. Vérifier `NEXT_PUBLIC_API_URL` dans `.env.local` (devrait être `http://localhost:3001`)
2. Redémarrer le serveur Next.js après modification des variables d'environnement

## Endpoints Disponibles

### Auth
- `POST /api/auth/login` - Login
- `POST /api/auth/register` - Register
- `GET /api/auth/me` - Current user (protected)

### Tenants
- `GET /api/tenants/:id/status` - Tenant status (protected)
- `GET /api/tenants/:id/metrics` - Metrics (protected)
- `GET /api/tenants/:id/workflows` - Workflows list (protected)
- `GET /api/tenants/:id/executions` - Executions history (protected)
- `POST /api/tenants/:id/workflows/:wfId/execute` - Execute workflow (protected)
- `GET /api/tenants/:id/articles` - Articles list (protected)
- `GET /api/tenants/:id/articles/:articleId` - Single article (protected)
- `GET /api/tenants/:id/clusters` - Clusters list (protected)

### Public
- `GET /health` - Health check
- `GET /` - API info

## Prochaines Étapes

1. **Connecter à PostgreSQL** : Remplacer les mock users par de vrais utilisateurs
2. **Hash des mots de passe** : Utiliser bcrypt au lieu de SHA256
3. **Vraies données** : Remplacer les mocks par des requêtes DB réelles
4. **Tests automatisés** : Ajouter des tests unitaires et e2e
5. **Validation** : Améliorer la validation des entrées avec Zod

## Support

Si vous rencontrez des problèmes :
1. Vérifier les logs dans les deux terminaux
2. Vérifier la console du navigateur (F12)
3. Tester les endpoints avec curl/Postman
4. Vérifier les variables d'environnement

---

Bon test ! 🚀
