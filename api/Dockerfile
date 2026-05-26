FROM node:20-alpine AS builder
WORKDIR /app
RUN apk add --no-cache openssl python3 make g++
COPY package*.json ./
COPY prisma ./prisma
RUN npm ci
RUN npx prisma generate
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN apk add --no-cache openssl
COPY package*.json ./
RUN npm ci --omit=dev
COPY tsconfig.json ./
COPY tsconfig.runtime.json ./
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
COPY prisma ./prisma
RUN mkdir -p uploads
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 CMD node -e "const req=require('http').get('http://localhost:3000/health',res=>{process.exit(res.statusCode===200?0:1)}); req.on('error',()=>process.exit(1)); setTimeout(()=>{req.destroy();process.exit(1);},4000);"
CMD ["sh", "-c", "npx prisma migrate deploy && TS_NODE_PROJECT=tsconfig.runtime.json node -r tsconfig-paths/register dist/server.js"]
