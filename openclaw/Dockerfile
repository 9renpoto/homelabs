FROM ghcr.io/openclaw/openclaw:2026.3.11

COPY openclaw.managed.json /usr/local/share/openclaw/openclaw.managed.json
COPY workspace/AGENTS.md /usr/local/share/openclaw/workspace/AGENTS.md
COPY workspace-smoke/AGENTS.md /usr/local/share/openclaw/workspace-smoke/AGENTS.md
COPY merge-managed-config.cjs /usr/local/bin/openclaw-merge-managed-config.cjs
COPY --chmod=755 entrypoint.sh /usr/local/bin/openclaw-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint.sh"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
