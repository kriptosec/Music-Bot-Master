import { config as dotenvConfig } from "dotenv";
import path from "path";

dotenvConfig({ path: path.resolve(__dirname, "../.env") });

function required(key: string): string {
  const value = process.env[key];
  if (!value) throw new Error(`Missing required env var: ${key}`);
  return value;
}

function optional(key: string, fallback: string): string {
  return process.env[key] ?? fallback;
}

export const config = {
  discord: {
    token: required("DISCORD_TOKEN"),
    clientId: optional("CLIENT_ID", ""),
    prefix: optional("BOT_PREFIX", "!"),
  },
  lavalink: {
    host: optional("LAVALINK_HOST", "127.0.0.1"),
    port: parseInt(optional("LAVALINK_PORT", "2333"), 10),
    password: optional("LAVALINK_PASSWORD", "r2dd2pass"),
    secure: optional("LAVALINK_SECURE", "false") === "true",
  },
  player: {
    inactiveTimeoutMs: parseInt(optional("INACTIVE_TIMEOUT_MS", "300000"), 10),
    defaultVolume: parseInt(optional("DEFAULT_VOLUME", "80"), 10),
  },
} as const;
