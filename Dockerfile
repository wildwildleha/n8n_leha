
# --- Build-time args you can override in Dokploy ---
ARG NODE_VERSION=22.21.0
ARG PNPM_VERSION=9.12.0

# ============================
# Stage 1: Build your n8n fork
# ============================
FROM n8nio/base:${NODE_VERSION} AS builder

WORKDIR /workspace
COPY . .

# 1) Activate the exact pnpm version expected by the monorepo
RUN corepack enable \
 && corepack prepare pnpm@${PNPM_VERSION} --activate

# 2) Install deps (use a cache mount for speed)
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# 3) Build the monorepo
RUN pnpm build

# ==============================================
# Stage 2: Final runtime (mirror upstream steps)
# ==============================================
FROM n8nio/base:${NODE_VERSION} AS runtime

ENV NODE_ENV=production
WORKDIR /home/node

# Copy compiled output into the runtime image (same layout upstream uses)
COPY --from=builder /workspace/compiled /usr/local/lib/node_modules/n8n
COPY docker/images/n8n/docker-entrypoint.sh /

# Upstream runtime tweaks used by n8n's official Dockerfile:
# - Rebuild sqlite3 native module
# - Install canvas binding used by pdfjs-dist
RUN cd /usr/local/lib/node_modules/n8n \
 && npm rebuild sqlite3 \
 && cd node_modules/pdfjs-dist \
 && npm install @napi-rs/canvas

# Link CLI and set up user home
RUN ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n \
 && mkdir -p /home/node/.n8n \
 && chown -R node:node /home/node

EXPOSE 5678
USER node
ENTRYPOINT ["tini","--","/docker-entrypoint.sh"]
