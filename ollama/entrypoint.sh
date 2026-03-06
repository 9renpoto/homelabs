#!/bin/sh
set -eu

OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5:0.5b}"

ollama serve &
serve_pid=$!

ready=0
for _ in $(seq 1 60); do
  if OLLAMA_HOST=http://127.0.0.1:11434 ollama list >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "ollama did not become ready in time" >&2
  kill "$serve_pid" 2>/dev/null || true
  wait "$serve_pid" 2>/dev/null || true
  exit 1
fi

OLLAMA_HOST=http://127.0.0.1:11434 ollama pull "$OLLAMA_MODEL"

wait "$serve_pid"
