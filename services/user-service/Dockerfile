# Multi-stage build for optimized production image
FROM node:18-alpine AS base

# Set working directory
WORKDIR /app

# Add non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Copy package files
COPY package*.json ./

# Development stage
FROM base AS development
ENV NODE_ENV=development
RUN npm ci --include=dev
COPY . .
USER nodejs
EXPOSE 3000
CMD ["dumb-init", "npm", "run", "dev"]

# Build stage
FROM base AS build
ENV NODE_ENV=production
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY --chown=nodejs:nodejs . .

# Remove development dependencies and unnecessary files
RUN rm -rf node_modules && \
    npm ci --only=production --silent && \
    rm -rf /tmp/* /var/cache/apk/* ~/.npm

# Production stage
FROM node:18-alpine AS production

# Security updates
RUN apk upgrade --no-cache

# Install dumb-init and security packages
RUN apk add --no-cache \
    dumb-init \
    tini \
    && rm -rf /var/cache/apk/*

# Create app directory and user
WORKDIR /app
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy built application from build stage
COPY --from=build --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nodejs:nodejs /app/src ./src
COPY --from=build --chown=nodejs:nodejs /app/package*.json ./

# Create directories for logs and ensure proper permissions
RUN mkdir -p logs && \
    chown -R nodejs:nodejs /app

# Security: run as non-root user
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health/liveness', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })" || exit 1

# Expose port
EXPOSE 3000

# Environment variables with defaults
ENV NODE_ENV=production \
    PORT=3000 \
    LOG_LEVEL=info \
    GRACEFUL_SHUTDOWN_TIMEOUT=30000

# Use tini for proper init and signal handling
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "src/app.js"]

# Labels for metadata (following OCI standards)
LABEL maintainer="engineering-team@company.com" \
      org.opencontainers.image.title="User Service" \
      org.opencontainers.image.description="User management microservice for e-commerce platform" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="Company" \
      org.opencontainers.image.source="https://github.com/company/aws-microservices-ecommerce" \
      org.opencontainers.image.documentation="https://github.com/company/aws-microservices-ecommerce/blob/main/services/user-service/README.md"
