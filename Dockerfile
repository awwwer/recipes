# Dockerfile for a universal Nx workspace build
# Base Node.js image
FROM node:20.10.0-alpine AS base

# Set working directory
WORKDIR /app

# Cache dependencies
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci --prefer-offline --no-audit

# Build the applications
FROM base AS build
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Disable Nx Daemon for reliable builds within Docker
ENV NX_DAEMON=false

# Build the Angular client for production
RUN npx nx build client --configuration=production

# Build the NestJS API for production
RUN npx nx build api --configuration=production

# Production image for the NestJS API
FROM node:20.10.0-alpine AS api-runner
WORKDIR /app
COPY --from=build /app/dist/apps/api ./dist/apps/api
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/package-lock.json ./package-lock.json
# Ensure production dependencies are installed for the API
RUN npm ci --only=production --prefer-offline --no-audit

EXPOSE 3000
CMD ["node", "dist/apps/api/main.js"]

# Development image for the NestJS API (hot reload)
FROM node:20.10.0-alpine AS api-dev
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --prefer-offline --no-audit
# Source code will be mounted in docker-compose for dev, so no COPY . . here
EXPOSE 3000
CMD ["npx", "nx", "serve", "api", "--host=0.0.0.0"]

# Production image for the Angular client
FROM nginx:alpine AS client-runner
# Copy the built Angular app from the build stage - UPDATED PATH HERE
COPY --from=build /app/dist/apps/client/browser /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

# Development image for the Angular client (hot reload)
FROM node:20.10.0-alpine AS client-dev
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --prefer-offline --no-audit
# Source code will be mounted in docker-compose for dev, so no COPY . . here
EXPOSE 4200
CMD ["npx", "nx", "serve", "client", "--host=0.0.0.0"]