# BYTHEWISE Workflows - N8N

Ce dossier contient les workflows N8N pour l'automatisation SEO BYTHEWISE.

## Structure

```
workflows/
├── export/                  # Workflows exportés (templates)
│   ├── WF1_seed_expansion.json
│   ├── WF2_clustering.json
│   └── WF3_generation.json
├── templates/              # Futures variations de workflows
└── scripts/               # Scripts d'aide
```

## Workflows

### WF1 - Seed Expansion

**Déclencheur** : Webhook POST

**Fonction** : Génère 200+ variations de mots-clés à partir d'un seed keyword

**Flow** :
1. Reçoit un seed keyword via webhook
2. Utilise OpenAI GPT-4 pour générer des variations
3. Enrichit chaque keyword avec métadonnées
4. Sauvegarde dans PostgreSQL
5. Déclenche automatiquement WF2

**Webhook URL** : `https://{subdomain}.app.bythewise.com/webhook/wf1-seed-expansion`

**Payload exemple** :
```json
{
  "seed_keyword": "digital marketing"
}
```

**Réponse** :
```json
{
  "success": true,
  "workflow": "WF1 - Seed Expansion",
  "seed_keyword": "digital marketing",
  "keywords_generated": 203,
  "next_workflow": "WF2 - Clustering will auto-trigger",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

### WF2 - Clustering

**Déclencheur** : Webhook POST (auto-déclenché par WF1)

**Fonction** : Regroupe les 200 keywords en ~60 clusters de 3 mots-clés par intention

**Flow** :
1. Récupère les keywords non-clustered depuis la DB
2. Les groupe en batches de 20
3. Utilise OpenAI pour clustering sémantique
4. Sauvegarde les clusters dans PostgreSQL
5. Marque les keywords comme "clustered"

**Webhook URL** : `https://{subdomain}.app.bythewise.com/webhook/wf2-clustering`

**Payload exemple** :
```json
{
  "seed_keyword": "digital marketing",
  "keywords_count": 203,
  "triggered_by": "WF1"
}
```

**Réponse** :
```json
{
  "success": true,
  "workflow": "WF2 - Clustering",
  "clusters_created": 67,
  "ready_for_generation": true,
  "next_workflow": "WF3 - Generation (scheduled Mon & Thu 8am)",
  "timestamp": "2025-01-15T10:35:00Z"
}
```

### WF3 - Article Generation

**Déclencheur** : Cron Schedule (Lundi & Jeudi à 8h)

**Expression Cron** : `0 8 * * 1,4`

**Fonction** : Génère et publie un article SEO complet avec image

**Flow** :
1. Récupère le prochain cluster non-publié
2. Génère l'article avec OpenAI GPT-4 (2000+ mots)
3. Génère l'image featured avec DALL-E 3
4. Publie sur WordPress via API
5. Sauvegarde dans la DB
6. Envoie une notification

**Output** :
- Article WordPress publié
- Featured image optimisée
- Métadonnées SEO (Yoast)
- Enregistrement dans la DB

## Configuration requise

### Credentials N8N

Chaque tenant doit configurer ces credentials dans N8N :

#### 1. OpenAI API
- **Type** : Header Auth
- **Name** : `OpenAI API`
- **Header** : `Authorization`
- **Value** : `Bearer sk-xxx...`

#### 2. PostgreSQL (Tenant)
- **Type** : PostgreSQL
- **Name** : `Tenant PostgreSQL`
- **Host** : `postgres-{tenant_id}`
- **Port** : `5432`
- **Database** : `n8n`
- **User** : `n8n`
- **Password** : (auto-généré lors du provisioning)

#### 3. WordPress API
- **Type** : Header Auth
- **Name** : `WordPress API`
- **Header** : `Authorization`
- **Value** : `Basic {base64(username:app_password)}`

### Variables d'environnement

Définies automatiquement dans le docker-compose :

- `WEBHOOK_BASE_URL` : URL de base pour les webhooks
- `WORDPRESS_URL` : URL du site WordPress
- `NOTIFICATION_WEBHOOK_URL` : Webhook pour notifications

## Import automatique

Les workflows sont importés automatiquement lors de la création d'un tenant :

```bash
# Automatique lors de create-tenant
./scripts/create-tenant.sh "Client Name" starter

# Manuel si nécessaire
./scripts/import-workflows.sh <tenant-id>
```

## Personnalisation

### Modifier un workflow

1. Exporter depuis N8N : Settings > Export
2. Modifier le JSON localement
3. Re-importer dans N8N

### Créer une variation

1. Copier un workflow existant
2. Renommer et ajuster
3. Placer dans `workflows/templates/`
4. Mettre à jour `import-workflows.sh`

## Tables PostgreSQL requises

Les workflows nécessitent ces tables dans la DB tenant :

```sql
-- Keywords table
CREATE TABLE keywords (
  id SERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL,
  seed_keyword VARCHAR(255),
  keyword VARCHAR(255) NOT NULL,
  position INTEGER,
  clustered BOOLEAN DEFAULT false,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Clusters table
CREATE TABLE clusters (
  id SERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL,
  cluster_id VARCHAR(100) UNIQUE NOT NULL,
  keywords TEXT[],
  intent VARCHAR(50),
  topic VARCHAR(255),
  priority VARCHAR(50),
  published BOOLEAN DEFAULT false,
  published_at TIMESTAMPTZ,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Articles table
CREATE TABLE articles (
  id SERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL,
  cluster_id VARCHAR(100),
  title TEXT,
  content TEXT,
  wordpress_url TEXT,
  wordpress_id INTEGER,
  published_at TIMESTAMPTZ,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Monitoring

### Métriques à surveiller

- Taux de succès des exécutions
- Temps moyen d'exécution
- Coût API (OpenAI, DALL-E)
- Articles publiés par semaine

### Logs

Accéder aux logs N8N :

```bash
docker logs n8n-tenant-{id} -f
```

### Webhooks de debug

Utiliser webhook.site pour tester les payloads :

1. Créer un endpoint sur webhook.site
2. Remplacer temporairement l'URL dans le workflow
3. Analyser le payload reçu

## Dépannage

### Workflow ne se déclenche pas

1. Vérifier que le workflow est activé
2. Tester le webhook avec curl :
   ```bash
   curl -X POST https://{subdomain}.app.bythewise.com/webhook/wf1-seed-expansion \
     -H "Content-Type: application/json" \
     -d '{"seed_keyword": "test"}'
   ```

### Erreur OpenAI

1. Vérifier la validité de l'API key
2. Vérifier les quotas OpenAI
3. Vérifier le format de la requête

### Erreur PostgreSQL

1. Vérifier que les tables existent
2. Vérifier les credentials
3. Vérifier la connexion réseau

### Article non publié sur WordPress

1. Vérifier l'URL WordPress
2. Vérifier les credentials
3. Vérifier que l'API REST est activée
4. Vérifier les permissions de l'utilisateur

## Ressources

- [Documentation N8N](https://docs.n8n.io/)
- [API OpenAI](https://platform.openai.com/docs/)
- [WordPress REST API](https://developer.wordpress.org/rest-api/)
- [N8N Webhook Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)
- [N8N Schedule Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.scheduletrigger/)

## Support

Pour toute question sur les workflows :
- Email : support@bythewise.com
- Documentation : https://docs.bythewise.com
