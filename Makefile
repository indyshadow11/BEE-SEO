.PHONY: help dev build start stop restart logs clean test deploy backup

# Variables
COMPOSE=docker-compose
COMPOSE_DEV=$(COMPOSE) -f docker-compose.yml

# Couleurs pour les messages
GREEN=\033[0;32m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m # No Color

help: ## Affiche cette aide
	@echo "$(GREEN)BYTHEWISE SaaS - Commandes disponibles$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

# Développement
dev: ## Lance l'environnement de développement
	@echo "$(GREEN)🚀 Démarrage de l'environnement de développement...$(NC)"
	@cp -n .env.example .env 2>/dev/null || true
	$(COMPOSE_DEV) up -d
	@echo "$(GREEN)✓ Environnement démarré !$(NC)"
	@echo "$(YELLOW)Dashboard: http://localhost:3000$(NC)"
	@echo "$(YELLOW)API: http://localhost:3001$(NC)"
	@echo "$(YELLOW)PostgreSQL: localhost:5432$(NC)"
	@echo "$(YELLOW)Redis: localhost:6379$(NC)"

build: ## Build les images Docker
	@echo "$(GREEN)🔨 Construction des images Docker...$(NC)"
	$(COMPOSE_DEV) build --no-cache

start: ## Démarre les services
	@echo "$(GREEN)▶️  Démarrage des services...$(NC)"
	$(COMPOSE_DEV) up -d

stop: ## Arrête les services
	@echo "$(YELLOW)⏸️  Arrêt des services...$(NC)"
	$(COMPOSE_DEV) stop

restart: ## Redémarre les services
	@echo "$(YELLOW)🔄 Redémarrage des services...$(NC)"
	$(COMPOSE_DEV) restart

# Logs
logs: ## Affiche les logs de tous les services
	$(COMPOSE_DEV) logs -f

logs-api: ## Affiche les logs de l'API
	$(COMPOSE_DEV) logs -f api

logs-dashboard: ## Affiche les logs du dashboard
	$(COMPOSE_DEV) logs -f dashboard

logs-postgres: ## Affiche les logs de PostgreSQL
	$(COMPOSE_DEV) logs -f postgres

logs-redis: ## Affiche les logs de Redis
	$(COMPOSE_DEV) logs -f redis

# Base de données
db-migrate: ## Exécute les migrations de base de données
	@echo "$(GREEN)📊 Exécution des migrations...$(NC)"
	$(COMPOSE_DEV) exec api npm run migrate

db-shell: ## Ouvre un shell PostgreSQL
	@echo "$(GREEN)🗄️  Connexion à PostgreSQL...$(NC)"
	$(COMPOSE_DEV) exec postgres psql -U admin -d bythewise_central

db-backup: ## Sauvegarde la base de données
	@echo "$(GREEN)💾 Sauvegarde de la base de données...$(NC)"
	@mkdir -p backups
	$(COMPOSE_DEV) exec -T postgres pg_dump -U admin bythewise_central > backups/backup-$$(date +%Y%m%d-%H%M%S).sql
	@echo "$(GREEN)✓ Sauvegarde terminée dans backups/$(NC)"

db-restore: ## Restaure la dernière sauvegarde (usage: make db-restore FILE=backup.sql)
	@echo "$(GREEN)📥 Restauration de la base de données...$(NC)"
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Erreur: Spécifiez le fichier avec FILE=backup.sql$(NC)"; \
		exit 1; \
	fi
	$(COMPOSE_DEV) exec -T postgres psql -U admin bythewise_central < $(FILE)

# Tests
test: ## Exécute les tests
	@echo "$(GREEN)🧪 Exécution des tests...$(NC)"
	$(COMPOSE_DEV) exec api npm test
	@echo "$(GREEN)✓ Tests terminés$(NC)"

test-api: ## Teste l'API
	@echo "$(GREEN)Testing API endpoints...$(NC)"
	@curl -f http://localhost:3001/health || echo "$(RED)API health check failed$(NC)"
	@curl -f http://localhost:3001/ || echo "$(RED)API root endpoint failed$(NC)"

# Nettoyage
clean: ## Nettoie les conteneurs et volumes
	@echo "$(RED)🧹 Nettoyage des conteneurs et volumes...$(NC)"
	$(COMPOSE_DEV) down -v
	@echo "$(GREEN)✓ Nettoyage terminé$(NC)"

clean-all: ## Nettoie tout (conteneurs, volumes, images)
	@echo "$(RED)🗑️  Nettoyage complet...$(NC)"
	$(COMPOSE_DEV) down -v --rmi all
	@echo "$(GREEN)✓ Nettoyage complet terminé$(NC)"

# Installation
install: ## Installe les dépendances
	@echo "$(GREEN)📦 Installation des dépendances...$(NC)"
	@cd api && npm install
	@cd dashboard && npm install
	@echo "$(GREEN)✓ Dépendances installées$(NC)"

setup: install ## Setup initial du projet
	@echo "$(GREEN)⚙️  Configuration initiale...$(NC)"
	@cp -n .env.example .env 2>/dev/null || true
	@cp -n api/.env.example api/.env 2>/dev/null || true
	@cp -n dashboard/.env.example dashboard/.env 2>/dev/null || true
	@echo "$(GREEN)✓ Configuration terminée$(NC)"
	@echo "$(YELLOW)N'oubliez pas d'éditer les fichiers .env avec vos valeurs$(NC)"

# Déploiement
deploy: ## Déploie en production
	@echo "$(GREEN)🚀 Déploiement en production...$(NC)"
	@if [ "$(ENV)" != "production" ]; then \
		echo "$(RED)Erreur: Définissez ENV=production pour déployer$(NC)"; \
		exit 1; \
	fi
	git pull origin main
	$(COMPOSE) -f docker-compose.yml build
	$(COMPOSE) -f docker-compose.yml up -d
	@echo "$(GREEN)✓ Déploiement terminé$(NC)"

# Monitoring
status: ## Affiche le statut des services
	@echo "$(GREEN)📊 Statut des services:$(NC)"
	$(COMPOSE_DEV) ps

stats: ## Affiche les statistiques des conteneurs
	@echo "$(GREEN)📈 Statistiques des conteneurs:$(NC)"
	docker stats --no-stream

health: ## Vérifie la santé des services
	@echo "$(GREEN)🏥 Vérification de la santé des services:$(NC)"
	@curl -s http://localhost:3001/health | jq '.' || echo "$(RED)API non disponible$(NC)"

# Par défaut
.DEFAULT_GOAL := help
