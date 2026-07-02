# ---------- BASE ----------
FROM node:22 AS base

WORKDIR /usr/src/app

COPY shared ./shared
COPY pnpm-lock.yaml ./
COPY turbo.json ./
COPY package.json ./
COPY pnpm-workspace.yaml ./
COPY tsconfig.base.json ./
COPY proto ./proto


COPY services/gateway/package*.json ./services/gateway/
COPY services/gateway/jest.config.js ./services/gateway/
COPY services/gateway/tsconfig.json ./services/gateway/
COPY services/gateway/src ./services/gateway/src/
COPY services/gateway/__tests__ ./services/gateway/__tests__/
#COPY services/gateway/prisma ./services/gateway/prisma/

# ---------- BUILD ----------
FROM base AS build

ENV NODE_ENV=development

RUN apt-get update && apt-get install -y protobuf-compiler

RUN corepack enable && corepack prepare pnpm@11.9.0 --activate

RUN pnpm fetch
RUN pnpm install --offline --frozen-lockfile

RUN mkdir -p ./services/gateway/src/grpc/generated
RUN pnpm run --filter gateway proto:generate

RUN pnpm --filter @shared/logger build
RUN pnpm --filter @shared/grpc-client-manager build
RUN pnpm --filter @shared/kafka-manager build
RUN pnpm --filter @shared/pg-boss-manager build

RUN pnpm --filter gateway build

RUN pnpm --filter gateway deploy /deploy --prod

RUN #pnpm --filter gateway deploy /deploy --prod --legacy


# ---------- PREDEPLOY ----------
FROM node:22 AS predeploy

CMD ["sh", "-c", "echo 'no predeploy step'"]


# ---------- DEV ----------
FROM build AS dev

ENV NODE_ENV=development

COPY --from=base /usr/local/bin/corepack /usr/local/bin/corepack
RUN corepack enable
RUN corepack prepare pnpm@11.9.0 --activate

RUN chown -R node:node /usr/src/app

USER node

EXPOSE 50051
EXPOSE 9090

CMD ["pnpm", "--filter", "gateway", "start"]

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:9090/livez || exit 1

# ---------- PROD ----------
FROM node:22 AS prod

WORKDIR /usr/src/app

ENV NODE_ENV=production


COPY --from=build /deploy .
#COPY --from=build /usr/src/app/services/gateway/node_modules ./services/gateway/node_modules
#COPY --from=build /usr/src/app/services/gateway/dist ./services/gateway/dist
#COPY --from=build /usr/src/app/shared ./shared

USER node

EXPOSE 50051
EXPOSE 9090


CMD ["node", "dist/app.js"]
#CMD ["node", "./services/gateway/dist/app.js"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:9090/livez || exit 1
