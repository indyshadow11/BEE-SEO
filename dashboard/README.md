# BYTHEWISE Dashboard - Next.js 15

Dashboard web pour la gestion de la plateforme SaaS BYTHEWISE.

## Stack

- **Next.js 15** - Framework React avec App Router
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **JWT** - Authentication

## Structure

```
dashboard/
├── src/
│   ├── app/
│   │   ├── (auth)/              # Pages d'authentification
│   │   │   ├── login/
│   │   │   └── register/
│   │   ├── dashboard/           # Pages dashboard
│   │   │   ├── page.tsx         # Dashboard principal
│   │   │   ├── workflows/       # Gestion workflows
│   │   │   └── articles/        # Articles publiés
│   │   ├── layout.tsx
│   │   └── page.tsx             # Page d'accueil
│   ├── components/
│   │   ├── MetricCard.tsx       # Affichage métriques
│   │   ├── WorkflowStatus.tsx   # Statut workflow
│   │   └── ArticlesList.tsx     # Liste articles
│   ├── lib/
│   │   ├── api.ts               # Client API
│   │   └── auth.ts              # Gestion auth JWT
│   ├── types/
│   │   └── index.ts             # Types TypeScript
│   └── middleware.ts            # Protection routes
```

## Features

### 🔐 Authentification

- Login/Register avec JWT
- Protection automatique des routes
- Session persistante (localStorage)
- Middleware Next.js pour la sécurité

### 📊 Dashboard Principal

- Vue d'ensemble des métriques
- Total executions
- Taux de succès
- Articles publiés
- Clusters en attente
- Historique des exécutions récentes

### 🔄 Gestion Workflows

- Status de WF1/WF2/WF3
- Dernière exécution
- Déclenchement manuel (WF1)
- Webhooks URLs
- Schedule info (WF3)

### 📰 Articles Publiés

- Liste de tous les articles
- Métadonnées (mots-clés, nombre de mots)
- Liens vers WordPress
- Statistiques globales

## Installation

```bash
cd dashboard

# Installer les dépendances
npm install

# Créer .env.local
cp .env.example .env.local

# Éditer .env.local
NEXT_PUBLIC_API_URL=http://localhost:3001
```

## Développement

```bash
# Lancer le serveur de développement
npm run dev

# Ouvrir http://localhost:3000
```

Le dashboard sera accessible sur `http://localhost:3000`.

## Build Production

```bash
# Build
npm run build

# Démarrer en production
npm start
```

## Configuration

### Variables d'environnement

Créez un fichier `.env.local` :

```env
# API Backend URL
NEXT_PUBLIC_API_URL=http://localhost:3001

# App URL
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

### API Backend

Le dashboard communique avec le backend Fastify via l'API client (`lib/api.ts`).

Endpoints utilisés :
- `POST /api/auth/login` - Connexion
- `POST /api/auth/register` - Inscription
- `GET /api/auth/me` - Utilisateur actuel
- `GET /api/tenants/:id/status` - Statut tenant
- `GET /api/tenants/:id/metrics` - Métriques
- `GET /api/tenants/:id/workflows` - Liste workflows
- `GET /api/tenants/:id/executions` - Historique exécutions
- `GET /api/tenants/:id/articles` - Articles publiés

## Authentification JWT

### Flow

1. **Login** : User soumet email/password
2. **Backend** : Vérifie credentials, génère JWT token
3. **Dashboard** : Stocke token dans localStorage
4. **Requests** : Envoie token dans header `Authorization: Bearer {token}`
5. **Middleware** : Vérifie token avant d'accéder aux routes protégées

### Stockage

```typescript
// Token stocké dans localStorage
localStorage.setItem('bythewise_auth_token', token);
localStorage.setItem('bythewise_user', JSON.stringify(user));
```

### Protection Routes

Le middleware protège automatiquement les routes `/dashboard/*` :

```typescript
// middleware.ts
if (pathname.startsWith('/dashboard') && !token) {
  return NextResponse.redirect(new URL('/login', request.url));
}
```

## Composants

### MetricCard

Affiche une métrique avec icône et tendance.

```tsx
<MetricCard
  title="Total Executions"
  value={1234}
  description="Last 30 days"
  icon={<span>🚀</span>}
  trend={{ value: 12, isPositive: true }}
/>
```

### WorkflowStatus

Affiche le statut d'un workflow avec dernière exécution.

```tsx
<WorkflowStatus
  workflow={{
    id: 'wf1',
    name: 'WF1 - Seed Expansion',
    active: true,
    webhookUrl: 'https://...',
    lastExecution: { ... }
  }}
  onExecute={() => handleExecute()}
/>
```

### ArticlesList

Liste paginée des articles publiés.

```tsx
<ArticlesList
  articles={[...]}
  isLoading={false}
/>
```

## Types TypeScript

Types principaux définis dans `src/types/index.ts` :

- `User` - Utilisateur
- `Tenant` - Tenant/Client
- `WorkflowExecution` - Exécution workflow
- `Article` - Article publié
- `Cluster` - Cluster de keywords
- `TenantMetrics` - Métriques tenant
- `WorkflowStatus` - Statut workflow

## API Client

Utilisation du client API :

```typescript
import { authAPI, workflowAPI, articlesAPI } from '@/lib/api';

// Login
const { token, user } = await authAPI.login(email, password);

// Get metrics
const metrics = await tenantAPI.getMetrics(tenantId);

// List workflows
const workflows = await workflowAPI.list(tenantId);

// Get articles
const articles = await articlesAPI.list(tenantId);
```

## Gestion Erreurs

```typescript
try {
  const data = await api.someEndpoint();
} catch (error) {
  if (error instanceof ApiError) {
    // Erreur API avec status code
    console.error(error.status, error.message);
  }
}
```

## Styling

Le dashboard utilise **Tailwind CSS** pour le styling.

Classes principales :
- Couleurs : `bg-blue-600`, `text-gray-900`
- Spacing : `p-6`, `mb-4`, `space-y-4`
- Layout : `flex`, `grid`, `max-w-7xl`
- States : `hover:bg-blue-700`, `focus:ring-2`

## Navigation

Navigation principale dans le layout du dashboard :
- 🏠 Dashboard - Vue d'ensemble
- 🔄 Workflows - Gestion WF1/WF2/WF3
- 📰 Articles - Articles publiés

## Responsive Design

Le dashboard est responsive :
- Mobile : Navigation hamburger, colonnes single
- Tablet : Grille 2 colonnes
- Desktop : Grille 4 colonnes, navigation complète

## Tests

```bash
# Lancer les tests
npm test

# Tests end-to-end
npm run e2e
```

## Déploiement

Le dashboard peut être déployé sur :
- **Vercel** (recommandé pour Next.js)
- **Netlify**
- **Docker** (avec le reste de l'infra)

### Vercel

```bash
# Installer Vercel CLI
npm i -g vercel

# Déployer
vercel
```

### Docker

Utiliser le Dockerfile fourni :

```bash
docker build -t bythewise-dashboard .
docker run -p 3000:3000 bythewise-dashboard
```

## Troubleshooting

### "API call failed"

Vérifiez que le backend Fastify est démarré sur le bon port :
```bash
cd api
npm run dev
```

### "Unauthorized"

Le token JWT a expiré. Reconnectez-vous.

### "Page not found"

Vérifiez que vous avez bien créé toutes les pages dans `/app/dashboard/`.

## Resources

- [Next.js 15 Docs](https://nextjs.org/docs)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [TypeScript](https://www.typescriptlang.org/docs)

## Support

Pour toute question sur le dashboard :
- Email : support@bythewise.com
- Documentation : https://docs.bythewise.com
