import type { Client, TextChannel } from "discord.js";
import type { Player, Track } from "lavalink-client";
import { logger } from "../utils/logger.js";
import { trackStartEmbed } from "../utils/embeds.js";
import { parseLoadError } from "../utils/format.js";
import { EmbedBuilder } from "discord.js";

export function registerLavalinkEvents(client: Client): void {
  const lavalink = client.lavalink;

  // ── Node events ───────────────────────────────────────────────────────────
  lavalink.nodeManager.on("connect", (node) => {
    // When youtube: false in application.yml the built-in Lavaplayer source is
    // disabled (it's broken for new YT ciphers), but the YouTube plugin still
    // handles all YouTube playback. However lavalink-client validates that
    // "youtube" appears in node.info.sourceManagers before allowing ytsearch.
    // Fix: if the YouTube plugin is loaded, inject "youtube" into sourceManagers
    // so the client's validation passes without enabling the broken source.
    if (node.info && !node.info.sourceManagers.includes("youtube")) {
      const hasPlugin = node.info.plugins?.some(
        (p: { name: string }) => p.name === "youtube-plugin" || p.name === "youtube"
      );
      if (hasPlugin) {
        node.info.sourceManagers.push("youtube");
        logger.info('YouTube plugin detectado — "youtube" añadido a sourceManagers (built-in desactivado).');
      }
    }

    logger.separator(`LAVALINK CONECTADO — nodo "${node.id}"`);
    logger.info(`Host: ${node.options.host}:${node.options.port}`);
    logger.info("El bot ya puede reproducir música.");
  });

  lavalink.nodeManager.on("disconnect", (node, reason) => {
    logger.warn(`Lavalink nodo "${node.id}" DESCONECTADO`);
    logger.warn(`Código: ${reason?.code ?? "?"} | Razón: ${reason?.reason ?? "desconocida"}`);
    logger.warn("El bot no podrá reproducir música hasta que se reconecte.");
  });

  lavalink.nodeManager.on("error", (node, error) => {
    logger.error(`Lavalink nodo "${node.id}" ERROR:`, error);
  });

  lavalink.nodeManager.on("reconnecting", (node) => {
    logger.info(`Lavalink nodo "${node.id}" reconectando...`);
  });

  // ── Track events ──────────────────────────────────────────────────────────
  lavalink.on("trackStart", async (player, track) => {
    if (!track) return;
    logger.info(`▶ Reproduciendo: "${track.info.title}" — ${track.info.author} [${track.info.duration ? Math.floor(track.info.duration / 1000) + "s" : "?"}] | Guild: ${player.guildId} | Cola restante: ${player.queue.tracks.length}`);

    const channel = getTextChannel(client, player);
    if (!channel) {
      logger.debug(`trackStart: sin canal de texto configurado para guild ${player.guildId}`);
      return;
    }
    const queueSize = player.queue.tracks.length;
    await channel.send({ embeds: [trackStartEmbed(track, queueSize)] }).catch((e) => {
      logger.warn(`No se pudo enviar trackStartEmbed: ${e.message}`);
    });
  });

  lavalink.on("trackEnd", async (player, track, payload) => {
    if (!track) return;
    logger.info(`⏹ Terminó: "${track.info.title}" | Razón: ${payload.reason} | Guild: ${player.guildId}`);
  });

  lavalink.on("trackError", async (player, track, payload) => {
    const rawMsg = (payload as { exception?: { message?: string } })?.exception?.message
      ?? (payload as { error?: string })?.error
      ?? String(payload);
    logger.error(`❌ Error en canción "${track?.info?.title ?? "desconocida"}" | Guild: ${player.guildId} | ${rawMsg}`);
    const channel = getTextChannel(client, player);
    if (!channel) return;
    const friendlyMsg = parseLoadError(rawMsg);
    const embed = new EmbedBuilder()
      .setColor(0xf04747)
      .setTitle(`❌ Error al reproducir: ${track?.info?.title ?? "canción desconocida"}`)
      .setDescription(`${friendlyMsg}\n\n*Se salta automáticamente.*`);
    await channel.send({ embeds: [embed] }).catch(() => null);
  });

  lavalink.on("trackStuck", async (player, track, payload) => {
    if (!track) return;
    logger.warn(`⚠ Canción atascada: "${track.info.title}" | Guild: ${player.guildId}`);
    const channel = getTextChannel(client, player);
    if (!channel) return;
    const embed = new EmbedBuilder()
      .setColor(0xfaa61a)
      .setDescription(`⚠️ **${track.info.title}** está atascada. Saltando...`);
    await channel.send({ embeds: [embed] }).catch(() => null);
    await player.skip().catch((e) => logger.error("Error al saltar canción atascada:", e));
  });

  lavalink.on("queueEnd", async (player, track, payload) => {
    logger.info(`✅ Cola terminada | Guild: ${player.guildId}`);
    const channel = getTextChannel(client, player);
    if (!channel) return;
    const embed = new EmbedBuilder()
      .setColor(0x5865f2)
      .setDescription("✅ Cola terminada. Usa `!play` para agregar más canciones.");
    await channel.send({ embeds: [embed] }).catch(() => null);
  });

  lavalink.on("playerCreate", (player) => {
    logger.debug(`Player creado | Guild: ${player.guildId} | VC: ${player.voiceChannelId}`);
  });

  lavalink.on("playerDestroy", (player, reason) => {
    logger.info(`Player destruido | Guild: ${player.guildId} | Razón: ${reason ?? "desconocida"}`);
  });

  lavalink.on("playerDisconnect", async (player, voiceChannelId) => {
    logger.info(`Player desconectado del canal ${voiceChannelId} | Guild: ${player.guildId}`);
  });
}

function getTextChannel(client: Client, player: Player): TextChannel | null {
  const channelId = player.textChannelId;
  if (!channelId) return null;
  const channel = client.channels.cache.get(channelId);
  if (!channel || !channel.isTextBased() || channel.isDMBased()) return null;
  return channel as TextChannel;
}
