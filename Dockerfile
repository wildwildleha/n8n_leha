# --- Builder ---
FROM n8nio/base:22.21.0 AS builder

USER root
# FIX 1: Install build tools AND symlink python -> python3
# The symlink ensures that scripts calling 'python' (like node-gyp) work correctly.
RUN if command -v apk > /dev/null; then \
      apk add --update python3 make g++ git && \
      ln -sf python3 /usr/bin/python; \
    else \
      apt-get update && apt-get install -y python3 make g++ git && \
      ln -sf python3 /usr/bin/python; \
    fi

WORKDIR /workspace
COPY . .

# Force pnpm v10 (required by repo)
RUN npm install -g pnpm@10.22.0 && pnpm -v

# Increase Node memory to prevent crashes
ENV NODE_OPTIONS="--max-old-space-size=8192"
ENV CYPRESS_INSTALL_BINARY=0

# FIX 2: Use --ignore-scripts (CRITICAL FIX)
# This prevents the build from crashing on flaky post-install steps like Cypress or Husky.
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --no-frozen-lockfile --ignore-scripts

RUN pnpm build

# --- Runtime (unchanged) ---
FROM n8nio/base:22.21.0 AS runtime
ENV NODE_ENV=production
WORKDIR /home/node
COPY --from=builder /workspace/compiled /usr/local/lib/node_modules/n8n
COPY docker/images/n8n/docker-entrypoint.sh /
RUN cd /usr/local/lib/node_modules/n8n \
 && npm rebuild sqlite3 \
 && cd node_modules/pdfjs-dist \
 && npm install @napi-rs/canvas
RUN ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n \
 && mkdir -p /home/node/.n8n \
 && chown -R node:node /home/node
EXPOSE 5678
USER node
ENTRYPOINT ["tini","--","/docker-entrypoint.sh"]
