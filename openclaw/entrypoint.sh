#!/bin/sh
set -eu

OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5:0.5b}"

openclaw config set models.providers.ollama.apiKey ollama-local
openclaw config set models.providers.ollama.baseUrl http://ollama:11434
openclaw config set models.providers.ollama.api ollama
openclaw config set agents.defaults.model.primary "ollama/${OLLAMA_MODEL}"
openclaw config set agents.defaults.bootstrapMaxChars 3000
openclaw config set agents.defaults.bootstrapTotalMaxChars 12000

exec docker-entrypoint.sh "$@"
