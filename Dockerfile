# ---------- BASE ----------
FROM node:22 AS base

WORKDIR /usr/src/app

# workspace metadata
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json tsconfig.base.json ./

# shared + proto
COPY shared ./shared
COPY proto ./proto

# gateway service
COPY services/gateway/package*.json ./services/gateway/
COPY services/gateway/tsconfig.json ./services/gateway/
COPY services/gateway/jest.config.js ./services/gateway/
COPY services/gateway/src ./services/gateway/src/
COPY services/gateway/__tests__ ./services/gateway/__tests__/

# ---------- BUILD ----------
FROM base AS build

ENV NODE_ENV=development

RUN apt-get update && apt-get install -y protobuf-compiler

RUN corepack enable
RUN pnpm install --frozen-lockfile

# grpc generation
RUN mkdir -p ./services/gateway/src/grpc/generated
RUN pnpm run --filter gateway proto:generate

# build shared libs
RUN pnpm --filter @shared/logger build
RUN pnpm --filter @shared/grpc-client-manager build
RUN pnpm --filter @shared/kafka-manager build
RUN pnpm --filter @shared/pg-boss-manager build

# build gateway
RUN pnpm --filter gateway build


# ---------- PREDEPLOY (NEW BEST PRACTICE) ----------
FROM build AS predeploy

# создаём чистый production bundle ТОЛЬКО для gateway
RUN pnpm deploy --filter gateway --prod /out

WORKDIR /out


# ---------- PROD ----------
FROM node:22 AS prod

WORKDIR /usr/src/app

ENV NODE_ENV=production

# берём только готовый deploy артефакт
COPY --from=predeploy /out ./

USER node

EXPOSE 50051
EXPOSE 9090

CMD ["node", "dist/app.js"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:9090/livez || exit 1