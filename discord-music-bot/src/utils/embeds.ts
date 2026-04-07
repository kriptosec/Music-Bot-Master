import { EmbedBuilder } from "discord.js";
import type { Track } from "lavalink-client";
import { formatDuration, getSourceEmoji, progressBar } from "./format.js";

const BRAND_COLOR = 0x7289da;
const SUCCESS_COLOR = 0x43b581;
const ERROR_COLOR = 0xf04747;
const INFO_COLOR = 0x5865f2;
const QUEUE_COLOR = 0x23272a;

export function errorEmbed(message: string): EmbedBuilder {
  return new EmbedBuilder().setColor(ERROR_COLOR).setDescription(`❌ ${message}`);
}

export function successEmbed(message: string): EmbedBuilder {
  return new EmbedBuilder().setColor(SUCCESS_COLOR).setDescription(`✅ ${message}`);
}

export function infoEmbed(title: string, description: string): EmbedBuilder {
  return new EmbedBuilder().setColor(INFO_COLOR).setTitle(title).setDescription(description);
}

export function nowPlayingEmbed(
  track: Track,
  position: number,
  volume: number,
  queueSize: number,
  loopMode: string
): EmbedBuilder {
  const src = getSourceEmoji(track.info.uri);
  const embed = new EmbedBuilder()
    .setColor(BRAND_COLOR)
    .setTitle("🎵 Reproduciendo ahora")
    .setDescription(
      `**[${track.info.title}](${track.info.uri ?? ""})**\n👤 ${track.info.author}`
    );

  if (track.info.artworkUrl) embed.setThumbnail(track.info.artworkUrl);

  if (!track.info.isStream) {
    const bar = progressBar(position, track.info.duration ?? 0);
    embed.addFields({
      name: "Progreso",
      value: `\`${formatDuration(position)}\` ${bar} \`${formatDuration(track.info.duration ?? 0)}\``,
      inline: false,
    });
  } else {
    embed.addFields({ name: "Estado", value: "`🔴 En vivo`", inline: true });
  }

  embed.addFields(
    { name: "Fuente", value: `${src}`, inline: true },
    { name: "Volumen", value: `\`${volume}%\``, inline: true },
    { name: "En cola", value: `\`${queueSize}\``, inline: true },
    { name: "Repetir", value: `\`${loopMode}\``, inline: true }
  );

  return embed;
}

export function trackAddedEmbed(track: Track, queuePosition: number): EmbedBuilder {
  const src = getSourceEmoji(track.info.uri);
  return new EmbedBuilder()
    .setColor(SUCCESS_COLOR)
    .setTitle("✅ Agregado a la cola")
    .setDescription(`${src} **[${track.info.title}](${track.info.uri ?? ""})**`)
    .addFields(
      { name: "Duración", value: `\`${formatDuration(track.info.duration ?? 0)}\``, inline: true },
      { name: "Posición", value: `\`#${queuePosition}\``, inline: true }
    )
    .setThumbnail(track.info.artworkUrl ?? null);
}

export function playlistAddedEmbed(name: string, count: number): EmbedBuilder {
  return new EmbedBuilder()
    .setColor(SUCCESS_COLOR)
    .setTitle("📃 Lista de reproducción agregada")
    .setDescription(`**${name}**\n\`${count}\` canciones agregadas a la cola.`);
}

export function trackStartEmbed(track: Track, queueSize: number): EmbedBuilder {
  const src = getSourceEmoji(track.info.uri);
  const embed = new EmbedBuilder()
    .setColor(BRAND_COLOR)
    .setTitle("🎵 Reproduciendo ahora")
    .setDescription(`${src} **[${track.info.title}](${track.info.uri ?? ""})**\n👤 ${track.info.author}`)
    .addFields(
      {
        name: "Duración",
        value: track.info.isStream ? "`🔴 En vivo`" : `\`${formatDuration(track.info.duration ?? 0)}\``,
        inline: true,
      },
      { name: "En cola", value: `\`${queueSize}\``, inline: true }
    );

  if (track.info.artworkUrl) embed.setThumbnail(track.info.artworkUrl);
  return embed;
}
