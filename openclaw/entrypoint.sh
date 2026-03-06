#!/bin/sh
set -eu

MANAGED_CONFIG_PATH="/usr/local/share/openclaw/openclaw.managed.json"
TARGET_CONFIG_PATH="/home/node/.openclaw/openclaw.json"
MERGER_SCRIPT_PATH="/usr/local/bin/openclaw-merge-managed-config.cjs"
OPENCLAW_HOME="/home/node/.openclaw"
WORKSPACE_TEMPLATES_ROOT="/usr/local/share/openclaw"

mkdir -p "$OPENCLAW_HOME"

if [ -f "$MANAGED_CONFIG_PATH" ]; then
	node "$MERGER_SCRIPT_PATH" "$TARGET_CONFIG_PATH" "$MANAGED_CONFIG_PATH" "$OPENCLAW_HOME" "$WORKSPACE_TEMPLATES_ROOT"
fi

exec docker-entrypoint.sh "$@"
