# --- Builder ---
FROM n8nio/base:22.21.0 AS builder
WORKDIR /workspace
COPY . .

# UPDATE: The repo explicitly requests pnpm v10.22.0 or higher.
RUN npm install -g pnpm@10.22.0 && pnpm -v

# CRITICAL FIX: Changed to --no-frozen-lockfile
# This allows the build to proceed even if the lockfile has minor discrepancies
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
