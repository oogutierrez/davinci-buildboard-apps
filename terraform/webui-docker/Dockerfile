# Build stage for React frontend
FROM node:18-alpine AS frontend-builder

WORKDIR /app/client

COPY client/package*.json ./

# Full install — vite and other build tools are dev deps
RUN npm install

# Fix: ensure all bin scripts are executable before building
RUN chmod +x node_modules/.bin/*

COPY client/ ./

RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
# Production-only is correct here — this is the runtime server
RUN npm install --only=production

COPY server/ ./server/

COPY --from=frontend-builder /app/client/dist ./client/dist

ENV NODE_ENV=production

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

CMD ["node", "server/index.js"]