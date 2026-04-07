import type { Client, TextChannel } from "discord.js";
import type { LavalinkManager, Player, Track } from "lavalink-client";
import { logger } from "../utils/logger.js";
import { trackStartEmbed } from "../utils/embeds.js";
import { EmbedBuilder } from "discord.js";

export function registerLavalinkEvents(client: Client): void {
  const lavalink = client.lavalink;

  // ── Node events (via nodeManager) ────────────────────────────────────────────
  lavalink.nodeManager.on("connect", (node) => {
    logger.info(`Lavalink node "${node.id}" conectado.`);
  });

  lavalink.nodeManager.on("disconnect", (node, reason) => {
    logger.warn(`Lavalink node "${node.id}" desconectado. Código: ${reason?.code ?? "?"} | Razón: ${reason?.reason ?? "desconocida"}`);
  });

  lavalink.nodeManager.on("error", (node, error) => {
    logger.error(`Lavalink node "${node.id}" error:`, error);
  });

  lavalink.nodeManager.on("reconnecting", (node) => {
    logger.info(`Lavalink node "${node.id}" reconectando...`);
  });

  // ── Player / Track events ─────────────────────────────────────────────────────
  lavalink.on("trackStart", async (player, track) => {
    if (!track) return;
    const channel = getTextChannel(client, player);
    if (!channel) return;
    const queueSize = player.queue.tracks.length;
    await channel.send({ embeds: [trackStartEmbed(track, queueSize)] }).catch(() => null);
  });

  lavalink.on("trackEnd", async (player, track, payload) => {
    if (!track) return;
    logger.debug(`Canción terminada: ${track.info.title} | Razón: ${payload.reason}`);
  });

  lavalink.on("trackError", async (player, track, payload) => {
    logger.error(`Error en canción "${track?.info?.title ?? "desconocida"}":`, payload);
    const channel = getTextChannel(client, player);
    if (!channel) return;
    const embed = new EmbedBuilder()
      .setColor(0xf04747)
      .setDescription(`❌ Error al reproducir **${track?.info?.title ?? "canción desconocida"}**.\nSe salta automáticamente.`);
    await channel.send({ embeds: [embed] }).catch(() => null);
  });

  lavalink.on("trackStuck", async (player, track, payload) => {
    if (!track) return;
    logger.warn(`Canción atascada: ${track.info.title}`);
    const channel = getTextChannel(client, player);
    if (!channel) return;
    const embed = new EmbedBuilder()
      .setColor(0xfaa61a)
      .setDescription(`⚠️ **${track.info.title}** está atascada. Saltando...`);
    await channel.send({ embeds: [embed] }).catch(() => null);
    await player.skip().catch(() => null);
  });

  lavalink.on("queueEnd", async (player, track, payload) => {
    logger.info(`Cola terminada en guild ${player.guildId}`);
    const channel = getTextChannel(client, player);
    if (!channel) return;
    const embed = new EmbedBuilder()
      .setColor(0x5865f2)
      .setDescription("✅ Cola terminada. Usa `!play` para agregar más canciones.");
    await channel.send({ embeds: [embed] }).catch(() => null);
  });

  lavalink.on("playerDestroy", (player, reason) => {
    logger.info(`Player destruido en guild ${player.guildId} | Razón: ${reason ?? "desconocida"}`);
  });

  lavalink.on("playerDisconnect", async (player, voiceChannelId) => {
    logger.info(`Player desconectado del canal ${voiceChannelId} en guild ${player.guildId}`);
  });
}

function getTextChannel(client: Client, player: Player): TextChannel | null {
  const channelId = player.textChannelId;
  if (!channelId) return null;
  const channel = client.channels.cache.get(channelId);
  if (!channel || !channel.isTextBased() || channel.isDMBased()) return null;
  return channel as TextChannel;
}
