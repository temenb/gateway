# ---------- BASE ----------
FROM node:22 AS base

WORKDIR /usr/src/app

COPY shared ./shared
COPY pnpm-lock.yaml ./
COPY turbo.json ./
COPY package.json ./
COPY pnpm-workspace.yaml ./
COPY tsconfig.json ./
COPY proto ./proto

COPY services/gateway/package*.json ./services/gateway/
COPY services/gateway/jest.config.js ./services/gateway/
COPY services/gateway/tsconfig.base.json ./services/gateway/
COPY services/gateway/src ./services/gateway/src/
COPY services/gateway/__tests__ ./services/gateway/__tests__/
#COPY services/gateway/prisma ./services/gateway/prisma/

# ---------- BUILD ----------
FROM base AS build

ENV NODE_ENV=development

RUN apt-get update && apt-get install -y protobuf-compiler

RUN corepack enable
RUN pnpm install --frozen-lockfile
RUN mkdir ./services/gateway/src/grpc/generated -p
RUN pnpm run --filter gateway proto:generate
RUN pnpm --filter @shared/logger build
RUN pnpm --filter @shared/grpc-client-manager build
#RUN pnpm --filter @shared/kafka-manager build
#RUN pnpm --filter @shared/pg-boss-manager buld
RUN pnpm --filter gateway build
RUN pnpm prune --prod

# ---------- DEV ----------
FROM build AS dev

ENV NODE_ENV=development

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

#RUN pnpm deploy --filter gateway /out

##COPY --from=build /usr/src/app /usr/src/app

COPY --from=build /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/services/gateway/node_modules ./services/gateway/node_modules
COPY --from=build /usr/src/app/services/gateway/dist ./services/gateway/dist
COPY --from=build /usr/src/app/shared ./shared


USER node

EXPOSE 50051
EXPOSE 9090

CMD ["node", "./services/gateway/dist/app.js"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:9090/livez || exit 1
