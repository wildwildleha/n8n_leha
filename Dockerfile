
# Stage 1: Build n8n from source
ARG NODE_VERSION=22.21.0
FROM n8nio/base:${NODE_VERSION} AS builder

WORKDIR /workspace
COPY . .
RUN corepack enable \
 && pnpm install --frozen-lockfile \
 && pnpm build

# Stage 2: Runtime image
FROM n8nio/base:${NODE_VERSION} AS runtime
ENV NODE_ENV=production
WORKDIR /home/node

COPY --from=builder /workspace/compiled /usr/local/lib/node_modules/n8n
COPY docker/images/n8n/docker-entrypoint.sh /

RUN ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n \
 && mkdir -p /home/node/.n8n \
 && chown -R node:node /home/node

EXPOSE 5678
USER node
ENTRYPOINT ["tini","--","/docker-entrypoint.sh"]
