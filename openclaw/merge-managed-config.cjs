// @ts-check

const fs = require("node:fs");

/**
 * JSON object represented as a string-indexed map.
 * @typedef {Record<string, unknown>} JsonObject
 */

/**
 * Returns true when the value is a plain JSON object.
 *
 * @param {unknown} value
 * @returns {value is JsonObject}
 */
const isObject = (value) => Boolean(value) && typeof value === "object" && !Array.isArray(value);

/**
 * Reads a JSON file and returns an empty object when missing/blank.
 *
 * @param {string} path
 * @returns {JsonObject}
 */
const readJson = (path) => {
  if (!fs.existsSync(path)) {
    return {};
  }

  const text = fs.readFileSync(path, "utf8").trim();
  if (!text) {
    return {};
  }

  try {
    return /** @type {JsonObject} */ (JSON.parse(text));
  } catch (error) {
    console.warn(`skip invalid JSON at ${path}: ${String(error)}`);
    return {};
  }
};

/**
 * Deep merges managed values into base values.
 *
 * @param {unknown} base
 * @param {unknown} managed
 * @returns {unknown}
 */
const deepMerge = (base, managed) => {
  if (!isObject(base) || !isObject(managed)) {
    return managed;
  }

  /** @type {JsonObject} */
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

/**
 * Ensures a nested key is an object and returns it.
 *
 * @param {JsonObject} parent
 * @param {string} key
 * @returns {JsonObject}
 */
const ensureObject = (parent, key) => {
  const value = parent[key];
  if (!isObject(value)) {
    parent[key] = {};
  }
  return /** @type {JsonObject} */ (parent[key]);
};

/**
 * Appends a model id if non-empty and not already present.
 *
 * @param {string[]} list
 * @param {string} value
 * @returns {void}
 */
const pushUnique = (list, value) => {
  const normalized = value.trim();
  if (!normalized) {
    return;
  }

  if (!list.includes(normalized)) {
    list.push(normalized);
  }
};

/**
 * Builds optional provider definitions from environment variables.
 *
 * Required variables per slot:
 * - <SLOT>_PROVIDER_ID
 * - <SLOT>_PROVIDER_API
 * - <SLOT>_BASE_URL
 * - <SLOT>_API_KEY
 * - <SLOT>_MODEL
 *
 * @param {string} slot
 * @returns {Array<{id: string, api: string, baseUrl: string, apiKey: string, model: string}>}
 */
const readOptionalProviders = (slot) => {
  const providerId = (process.env[`${slot}_PROVIDER_ID`] || "").trim();
  const providerApi = (process.env[`${slot}_PROVIDER_API`] || "").trim();
  const baseUrl = (process.env[`${slot}_BASE_URL`] || "").trim();
  const apiKey = (process.env[`${slot}_API_KEY`] || "").trim();
  const model = (process.env[`${slot}_MODEL`] || "").trim();

  if (!providerId || !providerApi || !baseUrl || !apiKey || !model) {
    return [];
  }

  return [
    {
      id: providerId,
      api: providerApi,
      baseUrl,
      apiKey,
      model,
    },
  ];
};

/**
 * Removes obsolete Discord keys that can break current schema validation.
 *
 * @param {JsonObject} cfg
 * @returns {JsonObject}
 */
const sanitizeLegacyDiscordKeys = (cfg) => {
  const discord = cfg.channels && isObject(cfg.channels) ? cfg.channels.discord : undefined;
  if (!isObject(discord)) {
    return cfg;
  }

  if (isObject(discord.dm) && Object.hasOwn(discord.dm, "policy")) {
    delete discord.dm.policy;
  }

  if (isObject(discord.guilds)) {
    for (const guildConfig of Object.values(discord.guilds)) {
      if (isObject(guildConfig) && Object.hasOwn(guildConfig, "ignoreOtherMentions")) {
        delete guildConfig.ignoreOtherMentions;
      }
    }
  }

  return cfg;
};

/**
 * Applies environment-driven provider defaults and model fallback rules.
 *
 * @param {JsonObject} cfg
 * @returns {JsonObject}
 */
const applyProviderEnv = (cfg) => {
  const providers = ensureObject(ensureObject(cfg, "models"), "providers");
  const defaultsModel = ensureObject(ensureObject(ensureObject(cfg, "agents"), "defaults"), "model");

  const geminiApiKey = (process.env.GEMINI_API_KEY || "").trim();
  const geminiModel = (process.env.GEMINI_MODEL || "gemini-2.5-flash-lite").trim();
  const ollamaModel = (process.env.OLLAMA_MODEL || "qwen2.5:3b-instruct-q4_K_M").trim();
  const localPrimaryPreferred = (process.env.LOCAL_PRIMARY || "").trim() === "1";
  const useOllamaSyncFallback = (process.env.OLLAMA_SYNC_FALLBACK || "").trim() === "1";
  const localPrimary = `ollama/${ollamaModel}`;
  const googlePrimary = `google/${geminiModel}`;
  /** @type {string[]} */
  const fallbacks = [];

  defaultsModel.primary = localPrimary;

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
    if (localPrimaryPreferred) {
      pushUnique(fallbacks, googlePrimary);
    } else {
      defaultsModel.primary = googlePrimary;
      if (useOllamaSyncFallback) {
        pushUnique(fallbacks, localPrimary);
      }
    }
  }

  const optionalProviders = [
    ...readOptionalProviders("ALT1"),
    ...readOptionalProviders("ALT2"),
  ];

  for (const optionalProvider of optionalProviders) {
    const provider = ensureObject(providers, optionalProvider.id);
    provider.api = optionalProvider.api;
    provider.baseUrl = optionalProvider.baseUrl;
    provider.apiKey = optionalProvider.apiKey;
    if (!Array.isArray(provider.models)) {
      provider.models = [];
    }

    pushUnique(fallbacks, `${optionalProvider.id}/${optionalProvider.model}`);
  }

  defaultsModel.fallbacks = fallbacks.filter((entry) => entry !== defaultsModel.primary);

  return cfg;
};

/**
 * Applies provider values to per-agent model files so existing agents pick up
 * the runtime provider changes.
 *
 * @param {JsonObject} cfg
 * @returns {JsonObject}
 */
const applyProviderEnvToAgentModels = (cfg) => {
  const providers = ensureObject(cfg, "providers");
  const geminiApiKey = (process.env.GEMINI_API_KEY || "").trim();

  if (geminiApiKey) {
    const googleProvider = ensureObject(providers, "google");
    googleProvider.api = "google-generative-ai";
    googleProvider.baseUrl = "https://generativelanguage.googleapis.com/v1beta";
    googleProvider.apiKey = geminiApiKey;

    if (!Array.isArray(googleProvider.models)) {
      googleProvider.models = [];
    }
  }

  const optionalProviders = [
    ...readOptionalProviders("ALT1"),
    ...readOptionalProviders("ALT2"),
  ];

  for (const optionalProvider of optionalProviders) {
    const provider = ensureObject(providers, optionalProvider.id);
    provider.api = optionalProvider.api;
    provider.baseUrl = optionalProvider.baseUrl;
    provider.apiKey = optionalProvider.apiKey;
    if (!Array.isArray(provider.models)) {
      provider.models = [];
    }
  }

  return cfg;
};

/**
 * Syncs all persisted agent model files under ~/.openclaw/agents/<id>/agent/models.json.
 *
 * @param {string} openclawHome
 * @returns {void}
 */
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

/**
 * Copies managed AGENTS.md templates into workspace directories.
 *
 * @param {string} openclawHome
 * @param {string} templatesRoot
 * @returns {void}
 */
const syncWorkspaceAgentDocs = (openclawHome, templatesRoot) => {
  /** @type {Array<{src: string, dest: string}>} */
  const mappings = [
    {
      src: `${templatesRoot}/workspace/AGENTS.md`,
      dest: `${openclawHome}/workspace/AGENTS.md`,
    },
    {
      src: `${templatesRoot}/workspace-smoke/AGENTS.md`,
      dest: `${openclawHome}/workspace-smoke/AGENTS.md`,
    },
  ];

  for (const mapping of mappings) {
    if (!fs.existsSync(mapping.src)) {
      continue;
    }

    fs.mkdirSync(mapping.dest.replace(/\/AGENTS\.md$/, ""), { recursive: true });
    fs.copyFileSync(mapping.src, mapping.dest);
  }
};

/**
 * Merges managed config with runtime config and writes the resulting file.
 *
 * @param {string} targetPath
 * @param {string} managedPath
 * @param {string} openclawHome
 * @param {string} templatesRoot
 * @returns {void}
 */
const mergeManagedConfig = (targetPath, managedPath, openclawHome, templatesRoot) => {
  const current = sanitizeLegacyDiscordKeys(readJson(targetPath));
  const managed = readJson(managedPath);

  const merged = /** @type {JsonObject} */ (deepMerge(current, managed));
  const next = applyProviderEnv(merged);

  fs.writeFileSync(targetPath, `${JSON.stringify(next, null, 2)}\n`, "utf8");
  syncAgentModelFiles(openclawHome);
  syncWorkspaceAgentDocs(openclawHome, templatesRoot);
};

const targetPath = process.argv[2];
const managedPath = process.argv[3];
const openclawHome = process.argv[4] || "/home/node/.openclaw";
const templatesRoot = process.argv[5] || "/usr/local/share/openclaw";

if (!targetPath || !managedPath) {
  throw new Error("Usage: node merge-managed-config.cjs <targetPath> <managedPath> [openclawHome]");
}

mergeManagedConfig(targetPath, managedPath, openclawHome, templatesRoot);
