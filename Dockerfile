# --- Builder ---
FROM n8nio/base:22.21.0 AS builder

# FIX: Install essential build tools (make, g++, python)
# Removed 'compat-openssl11' as it is not available/needed in this Alpine version
USER root
RUN if command -v apk > /dev/null; then \
      apk add --update python3 make g++ git; \
    else \
      apt-get update && apt-get install -y python3 make g++ git; \
    fi

WORKDIR /workspace
COPY . .

# FIX: Force pnpm v10 as required by the repo
RUN npm install -g pnpm@10.22.0 && pnpm -v

# FIX: Increase Node memory to prevent crashes during heavy install
ENV NODE_OPTIONS="--max-old-space-size=8192"
ENV CYPRESS_INSTALL_BINARY=0

# FIX: Install with no freeze to handle lockfile mismatches
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --no-frozen-lockfile

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
