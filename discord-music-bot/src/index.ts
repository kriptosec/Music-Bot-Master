import { Client, Collection, GatewayIntentBits } from "discord.js";
import { LavalinkManager } from "lavalink-client";
import { config } from "./config.js";
import { logger } from "./utils/logger.js";
import { allCommands } from "./commands/index.js";
import { registerReadyEvent } from "./events/ready.js";
import { registerMessageEvent } from "./events/messageCreate.js";
import { registerLavalinkEvents } from "./events/lavalink.js";
import { registerInteractionEvent } from "./events/interactionCreate.js";
import type { Command } from "./types.js";

// ─── Discord Client ────────────────────────────────────────────────────────────
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildVoiceStates,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

// ─── Command Registry ─────────────────────────────────────────────────────────
client.commands = new Collection<string, Command>();
for (const command of allCommands) {
  client.commands.set(command.name, command);
}
logger.info(`${client.commands.size} comandos registrados.`);

// ─── Lavalink Manager ─────────────────────────────────────────────────────────
client.lavalink = new LavalinkManager({
  nodes: [
    {
      authorization: config.lavalink.password,
      host: config.lavalink.host,
      port: config.lavalink.port,
      id: "main-node",
      secure: config.lavalink.secure,
      retryAmount: 999,
      retryDelay: 5_000,
    },
  ],
  sendToShard: (guildId, payload) => {
    const guild = client.guilds.cache.get(guildId);
    if (guild?.shard) guild.shard.send(payload);
  },
  autoSkip: true,
  playerOptions: {
    clientBasedPositionUpdateInterval: 150,
    defaultSearchPlatform: "ytsearch",
    volumeDecrementer: 0.75,
    onDisconnect: {
      autoReconnect: true,
      destroyPlayer: false,
    },
    onEmptyQueue: {
      destroyAfterMs: config.player.inactiveTimeoutMs,
    },
  },
  queueOptions: {
    maxPreviousTracks: 20,
  },
});

// ─── Forward raw gateway events to Lavalink ───────────────────────────────────
client.on("raw", (data) => {
  client.lavalink.sendRawData(data);
});

// ─── Register Event Handlers ──────────────────────────────────────────────────
registerReadyEvent(client);
registerMessageEvent(client);
registerLavalinkEvents(client);
registerInteractionEvent(client);

// ─── Global Error Handlers ────────────────────────────────────────────────────
process.on("unhandledRejection", (reason, promise) => {
  logger.error("Unhandled Rejection:", reason as Error);
});
process.on("uncaughtException", (error) => {
  logger.error("Uncaught Exception:", error);
  process.exit(1);
});

// ─── Start ────────────────────────────────────────────────────────────────────
logger.info("Iniciando Music Bot...");
logger.info(`Lavalink: ${config.lavalink.host}:${config.lavalink.port}`);
logger.info(`Prefijo: ${config.discord.prefix}`);

client.login(config.discord.token).catch((error) => {
  logger.error("Error al conectar con Discord:", error);
  process.exit(1);
});
