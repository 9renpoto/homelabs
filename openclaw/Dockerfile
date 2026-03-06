FROM ghcr.io/openclaw/openclaw:2026.3.2

COPY entrypoint.sh /usr/local/bin/openclaw-entrypoint.sh
RUN chmod +x /usr/local/bin/openclaw-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint.sh"]
