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

const current = sanitizeLegacyDiscordKeys(readJson(targetPath));
const managed = readJson(managedPath);
const next = deepMerge(current, managed);

fs.writeFileSync(targetPath, `${JSON.stringify(next, null, 2)}\n`, "utf8");
NODE
fi

exec docker-entrypoint.sh "$@"
