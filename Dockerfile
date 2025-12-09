# --- Builder ---
FROM n8nio/base:22.21.0 AS builder
WORKDIR /workspace
COPY . .

# FIX: Install pnpm via npm to bypass Corepack auto-detection overrides
# This ensures exactly v9.12.0 is used, preventing the v10 download
RUN npm install -g pnpm@9.12.0 && pnpm -v

RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile
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
