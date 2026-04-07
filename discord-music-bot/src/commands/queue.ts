import { EmbedBuilder } from "discord.js";
import type { Command, CommandContext } from "../types.js";
import { errorEmbed, successEmbed } from "../utils/embeds.js";
import { formatDuration, chunkArray, getSourceEmoji, truncate } from "../utils/format.js";

export const queue: Command = {
  name: "queue",
  aliases: ["q", "cola", "lista"],
  description: "Muestra la cola de reproducción. Puedes especificar una página.",
  usage: "[página]",
  category: "queue",

  async execute({ client, message, args }) {
    const player = client.lavalink.getPlayer(message.guild!.id);
    if (!player || (!player.queue.current && player.queue.tracks.length === 0)) {
      await message.reply({ embeds: [errorEmbed("La cola está vacía.")] });
      return;
    }

    const tracksPerPage = 10;
    const tracks = player.queue.tracks;
    const pages = chunkArray(tracks, tracksPerPage);
    const totalPages = Math.max(1, pages.length);
    const requestedPage = parseInt(args[0] ?? "1");
    const page = isNaN(requestedPage) ? 1 : Math.max(1, Math.min(requestedPage, totalPages));

    const embed = new EmbedBuilder()
      .setColor(0x23272a)
      .setTitle("📋 Cola de Reproducción");

    if (player.queue.current) {
      const cur = player.queue.current;
      const pos = player.position;
      embed.addFields({
        name: "▶️ Reproduciendo ahora",
        value:
          `${getSourceEmoji(cur.info.uri)} **[${truncate(cur.info.title, 60)}](${cur.info.uri ?? ""})**\n` +
          `👤 ${cur.info.author} • ⏱️ \`${formatDuration(pos)} / ${formatDuration(cur.info.duration ?? 0)}\``,
        inline: false,
      });
    }

    if (tracks.length > 0) {
      const currentPageTracks = pages[page - 1] ?? [];
      const startIndex = (page - 1) * tracksPerPage;
      const entries = currentPageTracks.map((t, i) =>
        `\`${startIndex + i + 1}.\` ${getSourceEmoji(t.info.uri)} **${truncate(t.info.title, 55)}**\n` +
        `     👤 ${t.info.author} • ⏱️ \`${formatDuration(t.info.duration ?? 0)}\``
      );

      const totalDuration = tracks.reduce((sum, t) => sum + (t.info.duration ?? 0), 0);

      embed.addFields({
        name: `📝 Cola (${tracks.length} canciones)`,
        value: entries.join("\n") || "—",
        inline: false,
      });

      const loopMode = player.repeatMode === "track" ? "🔁 Canción" : player.repeatMode === "queue" ? "🔁 Cola" : "❌";
      embed.setFooter({
        text: `Página ${page}/${totalPages} • Duración total: ${formatDuration(totalDuration)} • Repetir: ${loopMode}`,
      });
    } else {
      embed.addFields({ name: "📝 Cola", value: "La cola está vacía.", inline: false });
    }

    await message.reply({ embeds: [embed] });
  },
};

export const nowplaying: Command = {
  name: "nowplaying",
  aliases: ["np", "ahora", "current"],
  description: "Muestra información detallada de la canción actual.",
  category: "music",
  requiresPlayer: true,

  async execute({ client, message }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    const track = player.queue.current;
    if (!track) {
      await message.reply({ embeds: [errorEmbed("No hay nada reproduciéndose.")] });
      return;
    }

    const { nowPlayingEmbed } = await import("../utils/embeds.js");
    const loopModeMap = { track: "🔁 Canción", queue: "🔁 Cola", off: "❌ No" } as Record<string, string>;
    const loopMode = loopModeMap[player.repeatMode] ?? "❌ No";

    const embed = nowPlayingEmbed(track, player.position, player.volume, player.queue.tracks.length, loopMode);
    await message.reply({ embeds: [embed] });
  },
};

export const remove: Command = {
  name: "remove",
  aliases: ["eliminar", "quitar", "rm"],
  description: "Elimina una canción de la cola por su posición.",
  usage: "<posición>",
  category: "queue",
  requiresPlayer: true,
  requiresVoice: true,

  async execute({ client, message, args }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    if (player.queue.tracks.length === 0) {
      await message.reply({ embeds: [errorEmbed("La cola está vacía.")] });
      return;
    }
    const pos = parseInt(args[0]);
    if (isNaN(pos) || pos < 1 || pos > player.queue.tracks.length) {
      await message.reply({ embeds: [errorEmbed(`Posición inválida. La cola tiene \`${player.queue.tracks.length}\` canciones.`)] });
      return;
    }
    const removed = player.queue.tracks.splice(pos - 1, 1)[0];
    await message.reply({ embeds: [successEmbed(`🗑️ Eliminado: **${removed?.info.title ?? "canción desconocida"}**`)] });
  },
};

export const move: Command = {
  name: "move",
  aliases: ["mover", "mv"],
  description: "Mueve una canción de una posición a otra en la cola.",
  usage: "<de> <a>",
  category: "queue",
  requiresPlayer: true,
  requiresVoice: true,

  async execute({ client, message, args }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    const size = player.queue.tracks.length;
    if (size === 0) {
      await message.reply({ embeds: [errorEmbed("La cola está vacía.")] });
      return;
    }
    const from = parseInt(args[0]);
    const to = parseInt(args[1]);
    if (isNaN(from) || isNaN(to) || from < 1 || to < 1 || from > size || to > size) {
      await message.reply({ embeds: [errorEmbed(`Posiciones inválidas. La cola tiene \`${size}\` canciones.`)] });
      return;
    }
    if (from === to) {
      await message.reply({ embeds: [errorEmbed("Las posiciones son iguales.")] });
      return;
    }
    const [track] = player.queue.tracks.splice(from - 1, 1);
    player.queue.tracks.splice(to - 1, 0, track);
    await message.reply({ embeds: [successEmbed(`↕️ **${track?.info.title ?? "canción"}** movida de \`#${from}\` a \`#${to}\`.`)] });
  },
};

export const shuffle: Command = {
  name: "shuffle",
  aliases: ["mezclar", "aleatorio"],
  description: "Mezcla la cola de reproducción aleatoriamente.",
  category: "queue",
  requiresPlayer: true,
  requiresVoice: true,

  async execute({ client, message }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    if (player.queue.tracks.length === 0) {
      await message.reply({ embeds: [errorEmbed("La cola está vacía.")] });
      return;
    }
    await player.queue.shuffle();
    await message.reply({ embeds: [successEmbed(`🔀 Cola mezclada. \`${player.queue.tracks.length}\` canciones.`)] });
  },
};

export const clearQueue: Command = {
  name: "clear",
  aliases: ["limpiar", "vaciar"],
  description: "Limpia toda la cola de reproducción.",
  category: "queue",
  requiresPlayer: true,
  requiresVoice: true,

  async execute({ client, message }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    if (player.queue.tracks.length === 0) {
      await message.reply({ embeds: [errorEmbed("La cola ya está vacía.")] });
      return;
    }
    const count = player.queue.tracks.length;
    player.queue.tracks.splice(0);
    await message.reply({ embeds: [successEmbed(`🗑️ Cola limpiada. \`${count}\` canciones eliminadas.`)] });
  },
};

export const loop: Command = {
  name: "loop",
  aliases: ["repetir", "repeat"],
  description: "Cambia el modo de repetición. Opciones: track, queue, off.",
  usage: "<track|queue|off>",
  category: "queue",
  requiresPlayer: true,
  requiresVoice: true,

  async execute({ client, message, args }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    const mode = (args[0] ?? "").toLowerCase();

    if (["track", "cancion", "song", "1"].includes(mode)) {
      await player.setRepeatMode("track");
      await message.reply({ embeds: [successEmbed("🔁 Repitiendo la canción actual.")] });
    } else if (["queue", "cola", "all", "todo", "2"].includes(mode)) {
      await player.setRepeatMode("queue");
      await message.reply({ embeds: [successEmbed("🔁 Repitiendo toda la cola.")] });
    } else if (["off", "no", "apagar", "0"].includes(mode)) {
      await player.setRepeatMode("off");
      await message.reply({ embeds: [successEmbed("❌ Repetición desactivada.")] });
    } else {
      // Toggle through modes
      const current = player.repeatMode;
      if (current === "off") {
        await player.setRepeatMode("track");
        await message.reply({ embeds: [successEmbed("🔁 Repitiendo la canción actual.")] });
      } else if (current === "track") {
        await player.setRepeatMode("queue");
        await message.reply({ embeds: [successEmbed("🔁 Repitiendo toda la cola.")] });
      } else {
        await player.setRepeatMode("off");
        await message.reply({ embeds: [successEmbed("❌ Repetición desactivada.")] });
      }
    }
  },
};
