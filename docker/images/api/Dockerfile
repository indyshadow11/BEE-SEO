FROM node:20-alpine

WORKDIR /app

# Installer les dépendances système nécessaires
RUN apk add --no-cache \
    python3 \
    make \
    g++

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer les dépendances
RUN npm ci --only=production && \
    npm cache clean --force

# Copier le code source
COPY . .

# Exposer le port
EXPOSE 3001

# Démarrer l'application
CMD ["npm", "start"]
