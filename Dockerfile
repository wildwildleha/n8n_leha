
# Stage 1: Use n8n's base environment (matches their official build approach)
ARG NODE_VERSION=22.21.0
FROM n8nio/base:${NODE_VERSION} AS builder

# Set working directory
WORKDIR /workspace

# Copy your repo (Dokploy will clone your repo and provide the context here)
# If your repo is the full n8n monorepo, copy all sources:
COPY . .

# Install dependencies & build (n8n monorepo uses pnpm/turborepo)
# Your fork should keep the same scripts (see n8n repo)
RUN corepack enable \
 && pnpm install --frozen-lockfile \
 && pnpm build

# Stage 2: Final runtime image (mirrors official Dockerfile layout)
FROM n8nio/base:${NODE_VERSION} AS runtime
ENV NODE_ENV=production
WORKDIR /home/node

# Copy compiled app artifact into runtime (same pattern used by n8n’s official Dockerfile)
COPY --from=builder /workspace/compiled /usr/local/lib/node_modules/n8n
COPY docker/images/n8n/docker-entrypoint.sh /

# Link CLI, create user dir
RUN ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n \
 && mkdir -p /home/node/.n8n \
 && chown -R node:node /home/node

EXPOSE 5678
USER node
ENTRYPOINT ["tini","--","/docker-entrypoint.sh"]
