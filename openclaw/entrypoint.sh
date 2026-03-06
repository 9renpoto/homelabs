#!/bin/sh
set -eu

MANAGED_CONFIG_PATH="/usr/local/share/openclaw/openclaw.managed.json"
TARGET_CONFIG_PATH="/home/node/.openclaw/openclaw.json"

mkdir -p /home/node/.openclaw

if [ -f "$MANAGED_CONFIG_PATH" ]; then
	node - "$TARGET_CONFIG_PATH" "$MANAGED_CONFIG_PATH" <<'NODE'
const fs = require("node:fs");

const targetPath = process.argv[2];
const managedPath = process.argv[3];

const readJson = (path) => {
	if (!fs.existsSync(path)) {
		return {};
	}
	const text = fs.readFileSync(path, "utf8").trim();
	if (!text) {
		return {};
	}
	return JSON.parse(text);
};

const isObject = (value) => value && typeof value === "object" && !Array.isArray(value);

const deepMerge = (base, managed) => {
	if (!isObject(base) || !isObject(managed)) {
		return managed;
	}

	const merged = { ...base };
	for (const [key, managedValue] of Object.entries(managed)) {
		const baseValue = merged[key];
		if (isObject(baseValue) && isObject(managedValue)) {
			merged[key] = deepMerge(baseValue, managedValue);
			continue;
		}
		merged[key] = managedValue;
	}
	return merged;
};

const sanitizeLegacyDiscordKeys = (cfg) => {
	if (!isObject(cfg)) {
		return cfg;
	}

	const discord = cfg.channels?.discord;
	if (isObject(discord)) {
		if (isObject(discord.dm) && Object.prototype.hasOwnProperty.call(discord.dm, "policy")) {
			delete discord.dm.policy;
		}

		if (isObject(discord.guilds)) {
			for (const guildConfig of Object.values(discord.guilds)) {
				if (isObject(guildConfig) && Object.prototype.hasOwnProperty.call(guildConfig, "ignoreOtherMentions")) {
					delete guildConfig.ignoreOtherMentions;
				}
			}
		}
	}

	return cfg;
};

const ensureObject = (parent, key) => {
	if (!isObject(parent[key])) {
		parent[key] = {};
	}
	return parent[key];
};

const applyProviderEnv = (cfg) => {
	if (!isObject(cfg)) {
		return cfg;
	}

	const providers = ensureObject(ensureObject(cfg, "models"), "providers");
	const defaultsModel = ensureObject(ensureObject(ensureObject(cfg, "agents"), "defaults"), "model");

	const geminiApiKey = (process.env.GEMINI_API_KEY || "").trim();
	const geminiModel = (process.env.GEMINI_MODEL || "gemini-2.5-flash").trim();
	const ollamaModel = (process.env.OLLAMA_MODEL || "qwen2.5:0.5b").trim();

	if (geminiApiKey) {
		const googleProvider = ensureObject(providers, "google");
		googleProvider.api = "google-generative-ai";
		if (typeof googleProvider.baseUrl !== "string" || !googleProvider.baseUrl.trim()) {
			googleProvider.baseUrl = "https://generativelanguage.googleapis.com/v1beta";
		}
		if (!Array.isArray(googleProvider.models)) {
			googleProvider.models = [];
		}
		googleProvider.apiKey = geminiApiKey;
		defaultsModel.primary = `google/${geminiModel}`;
		return cfg;
	}

	if ((defaultsModel.primary || "").startsWith("google/")) {
		defaultsModel.primary = `ollama/${ollamaModel}`;
	}

	return cfg;
};

const applyProviderEnvToAgentModels = (cfg) => {
	if (!isObject(cfg)) {
		return cfg;
	}

	const providers = ensureObject(cfg, "providers");
	const geminiApiKey = (process.env.GEMINI_API_KEY || "").trim();

	if (!geminiApiKey) {
		return cfg;
	}

	const googleProvider = ensureObject(providers, "google");
	googleProvider.api = "google-generative-ai";
	googleProvider.baseUrl = "https://generativelanguage.googleapis.com/v1beta";
	googleProvider.apiKey = geminiApiKey;
	if (!Array.isArray(googleProvider.models)) {
		googleProvider.models = [];
	}

	return cfg;
};

const syncAgentModelFiles = (openclawHome) => {
	const agentsRoot = `${openclawHome}/agents`;
	if (!fs.existsSync(agentsRoot)) {
		return;
	}

	for (const entry of fs.readdirSync(agentsRoot, { withFileTypes: true })) {
		if (!entry.isDirectory()) {
			continue;
		}
		const modelPath = `${agentsRoot}/${entry.name}/agent/models.json`;
		if (!fs.existsSync(modelPath)) {
			continue;
		}

		const current = readJson(modelPath);
		const next = applyProviderEnvToAgentModels(current);
		fs.writeFileSync(modelPath, `${JSON.stringify(next, null, 2)}\n`, "utf8");
	}
};

const current = sanitizeLegacyDiscordKeys(readJson(targetPath));
const managed = readJson(managedPath);
const next = applyProviderEnv(deepMerge(current, managed));

fs.writeFileSync(targetPath, `${JSON.stringify(next, null, 2)}\n`, "utf8");
syncAgentModelFiles("/home/node/.openclaw");
NODE
fi

exec docker-entrypoint.sh "$@"
