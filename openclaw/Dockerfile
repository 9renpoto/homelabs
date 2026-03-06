FROM ghcr.io/openclaw/openclaw:2026.3.2

COPY openclaw.managed.json /usr/local/share/openclaw/openclaw.managed.json
COPY merge-managed-config.cjs /usr/local/bin/openclaw-merge-managed-config.cjs
COPY --chmod=755 entrypoint.sh /usr/local/bin/openclaw-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint.sh"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
