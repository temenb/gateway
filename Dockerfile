# ---------- BASE ----------
FROM node:22 AS base

WORKDIR /usr/src/app

COPY shared ./shared
COPY pnpm-lock.yaml ./
COPY turbo.json ./
COPY package.json ./
COPY pnpm-workspace.yaml ./
COPY tsconfig.json ./

COPY services/gateway/package*.json ./services/gateway/
COPY services/gateway/jest.config.js ./services/gateway/
COPY services/gateway/tsconfig.json ./services/gateway/
COPY services/gateway/src ./services/gateway/src/
COPY services/gateway/__tests__ ./services/gateway/__tests__/

# ---------- BUILD ----------
FROM base AS build

ENV NODE_ENV=development

RUN corepack enable
RUN pnpm install --frozen-lockfile
RUN pnpm run proto:generate
RUN pnpm run --filter gateway build
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

#COPY --from=build /usr/src/app /usr/src/app
COPY --from=build /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/dist ./dist

USER node

EXPOSE 50051
EXPOSE 9090

CMD ["node", "dist/services/gateway/src/app.js"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:9090/livez || exit 1
