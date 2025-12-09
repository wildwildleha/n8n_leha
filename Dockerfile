# --- Builder ---
FROM n8nio/base:22.21.0 AS builder

# FIX 1: Install essential build tools (make, g++, python) required for native modules
# We check for apk (Alpine) or apt (Debian) to be safe, though n8n is usually Alpine.
USER root
RUN if command -v apk > /dev/null; then \
      apk add --update python3 make g++ git compat-openssl11; \
    else \
      apt-get update && apt-get install -y python3 make g++ git; \
    fi

WORKDIR /workspace
COPY . .

# FIX 2: Force pnpm v10 as required by the repo
RUN npm install -g pnpm@10.22.0 && pnpm -v

# FIX 3: Increase Node memory to prevent crashes during heavy install
ENV NODE_OPTIONS="--max-old-space-size=8192"
# Skip downloading heavy Cypress binaries which often fail in CI
ENV CYPRESS_INSTALL_BINARY=0

# FIX 4: Install with no freeze to handle lockfile mismatches
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
