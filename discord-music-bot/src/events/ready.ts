import type { Client } from "discord.js";
import { ActivityType, REST, Routes, SlashCommandBuilder } from "discord.js";
import { config } from "../config.js";
import { logger } from "../utils/logger.js";

// ─── Slash command definitions ────────────────────────────────────────────────
const slashCommands = [
  new SlashCommandBuilder()
    .setName("play")
    .setDescription("Reproduce una canción o playlist.")
    .addStringOption((o) =>
      o.setName("cancion").setDescription("Nombre de la canción o URL de YouTube/Spotify/SoundCloud").setRequired(true)
    ),

  new SlashCommandBuilder()
    .setName("skip")
    .setDescription("Salta la canción actual."),

  new SlashCommandBuilder()
    .setName("pause")
    .setDescription("Pausa o reanuda la reproducción."),

  new SlashCommandBuilder()
    .setName("stop")
    .setDescription("Detiene la reproducción y vacía la cola."),

  new SlashCommandBuilder()
    .setName("nowplaying")
    .setDescription("Muestra la canción actual."),

  new SlashCommandBuilder()
    .setName("queue")
    .setDescription("Muestra la cola de canciones.")
    .addIntegerOption((o) =>
      o.setName("pagina").setDescription("Número de página").setRequired(false).setMinValue(1)
    ),

  new SlashCommandBuilder()
    .setName("volume")
    .setDescription("Ajusta el volumen (0-200).")
    .addIntegerOption((o) =>
      o.setName("nivel").setDescription("Nivel de volumen (0-200)").setRequired(true).setMinValue(0).setMaxValue(200)
    ),
].map((cmd) => cmd.toJSON());

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
      activities: [{ name: `${config.discord.prefix}help | /play`, type: ActivityType.Listening }],
      status: "online",
    });

    // ── Register slash commands ──────────────────────────────────────────────
    try {
      const rest = new REST().setToken(config.discord.token);
      await rest.put(Routes.applicationCommands(readyClient.user.id), { body: slashCommands });
      logger.info(`${slashCommands.length} slash commands registrados globalmente.`);
    } catch (err) {
      logger.error("Error al registrar slash commands:", err);
    }

    // ── Connect Lavalink ─────────────────────────────────────────────────────
    logger.info("Iniciando conexión con Lavalink...");
    try {
      await client.lavalink.init({ ...readyClient.user });
      logger.info("LavalinkManager iniciado. Esperando conexión del nodo...");
    } catch (error) {
      logger.error("Error crítico al iniciar LavalinkManager:", error);
    }
  });
}
