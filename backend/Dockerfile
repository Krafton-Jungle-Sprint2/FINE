# Dockerfile
FROM node:20-slim AS base
RUN apt-get update && apt-get install -y --no-install-recommends curl openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# deps 레이어: 패키지 설치(캐시 최적화)
FROM base AS deps
COPY package*.json ./
COPY prisma/schema.prisma ./prisma/schema.prisma
RUN npm ci
# prisma client 생성 (node_modules에 생성)
RUN npx prisma generate

# 개발용
FROM base AS development
# dev 의존성도 필요하면 여기서 추가 설치
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package*.json ./
COPY --from=deps /app/prisma ./prisma
# 전체 소스
COPY . .
# 권한
RUN useradd -m app && chown -R app:app /app
USER app
ENV NODE_ENV=development
EXPOSE 4000 5000 5555 9229
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1
CMD ["npm", "run", "dev"]

# 프로덕션용
FROM base AS production
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package*.json ./
COPY --from=deps /app/prisma ./prisma
COPY ./src ./src
EXPOSE 4000 5000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1
CMD ["npm", "start"]
