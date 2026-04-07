import type { Client } from "discord.js";
import { ActivityType } from "discord.js";
import { config } from "../config.js";
import { logger } from "../utils/logger.js";

export function registerReadyEvent(client: Client): void {
  client.once("ready", async (readyClient) => {
    logger.separator("BOT CONECTADO A DISCORD");
    logger.info(`Tag:          ${readyClient.user.tag}`);
    logger.info(`ID:           ${readyClient.user.id}`);
    logger.info(`Servidores:   ${readyClient.guilds.cache.size}`);
    logger.info(`Prefijo:      ${config.discord.prefix}`);
    logger.info(`Comandos:     ${client.commands.size}`);
    logger.info(`Lavalink:     ${config.lavalink.host}:${config.lavalink.port}`);

    readyClient.user.setPresence({
      activities: [{ name: `${config.discord.prefix}help | Música`, type: ActivityType.Listening }],
      status: "online",
    });

    logger.info("Iniciando conexión con Lavalink...");
    try {
      await client.lavalink.init({ ...readyClient.user });
      logger.info("LavalinkManager iniciado. Esperando conexión del nodo...");
    } catch (error) {
      logger.error("Error crítico al iniciar LavalinkManager:", error);
    }
  });
}
