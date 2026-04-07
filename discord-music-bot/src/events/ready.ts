import type { Client } from "discord.js";
import { ActivityType } from "discord.js";
import { config } from "../config.js";
import { logger } from "../utils/logger.js";

export function registerReadyEvent(client: Client): void {
  client.once("ready", async (readyClient) => {
    logger.info(`Bot conectado como ${readyClient.user.tag} (${readyClient.user.id})`);
    logger.info(`Servidor(es): ${readyClient.guilds.cache.size}`);

    readyClient.user.setPresence({
      activities: [
        {
          name: `${config.discord.prefix}help | Música`,
          type: ActivityType.Listening,
        },
      ],
      status: "online",
    });

    // Connect lavalink after bot is ready
    try {
      await client.lavalink.init({ ...readyClient.user });
      logger.info("LavalinkManager iniciado correctamente.");
    } catch (error) {
      logger.error("Error al iniciar LavalinkManager:", error);
    }
  });
}
