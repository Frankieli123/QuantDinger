# QuantDinger Frontend Dockerfile
# Stage 1: Build
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (prefer npm)
RUN npm install --legacy-peer-deps

# Copy source code
COPY . .

# Build production version
RUN npm run build

# Stage 2: Production image (using nginx)
FROM nginx:alpine

# Copy build artifacts
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration as template (supports env var substitution)
COPY deploy/nginx-docker.conf /etc/nginx/templates/default.conf.template

# Default backend host (override via BACKEND_HOST)
ENV BACKEND_HOST=backend
# Only substitute BACKEND_HOST variable (preserve nginx variables like $host, $remote_addr)
ENV NGINX_ENVSUBST_FILTER=BACKEND_HOST

# Expose port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
