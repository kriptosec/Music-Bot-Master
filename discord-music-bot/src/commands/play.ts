import type { Track } from "lavalink-client";
import type { Command, CommandContext } from "../types.js";
import { errorEmbed, trackAddedEmbed, playlistAddedEmbed } from "../utils/embeds.js";
import { cleanQuery } from "../utils/format.js";
import { logger } from "../utils/logger.js";

export const play: Command = {
  name: "play",
  aliases: ["p", "tocar", "reproducir"],
  description: "Reproduce una canción o la agrega a la cola. Soporta YouTube, Spotify y SoundCloud.",
  usage: "<canción o URL>",
  category: "music",
  requiresVoice: true,

  async execute({ client, message, args }) {
    if (!args.length) {
      await message.reply({ embeds: [errorEmbed("Debes especificar una canción o URL.")] });
      return;
    }

    const { query, stripped } = cleanQuery(args.join(" "));
    const guild = message.guild!;
    const member = message.member!;
    const voiceChannel = member.voice.channel!;

    let player = client.lavalink.getPlayer(guild.id);

    if (!player) {
      try {
        player = await client.lavalink.createPlayer({
          guildId: guild.id,
          voiceChannelId: voiceChannel.id,
          textChannelId: message.channel.id,
          selfDeaf: true,
          selfMute: false,
          volume: 80,
          instaUpdateFiltersFix: true,
          applyVolumeAsFilter: false,
        });
      } catch {
        await message.reply({ embeds: [errorEmbed("⏳ Lavalink aún está iniciando. Espera unos segundos e intentá de nuevo.")] });
        return;
      }
    }

    if (!player.connected) {
      await player.connect();
    }

    player.textChannelId = message.channel.id;

    const loadingMsg = await message.reply({
      content: stripped
        ? "🔍 Buscando... *(era una radio/mix de YouTube, reproduciré solo el video)*"
        : "🔍 Buscando...",
    });

    try {
      const result = await player.search(
        { query, source: query.startsWith("http") ? undefined : "ytsearch" },
        message.author
      );

      if (result.loadType === "empty" || result.loadType === "error") {
        await loadingMsg.edit({ content: "", embeds: [errorEmbed(`No encontré resultados para: \`${query}\``)] });
        if (!player.playing && player.queue.tracks.length === 0) {
          await player.destroy();
        }
        return;
      }

      if (result.loadType === "playlist") {
        await player.queue.add(result.tracks);
        await loadingMsg.edit({ content: "", embeds: [playlistAddedEmbed(result.playlist?.name ?? "Lista desconocida", result.tracks.length)] });
      } else {
        const track = result.tracks[0];
        await player.queue.add(track);
        if (player.playing) {
          await loadingMsg.edit({ content: "", embeds: [trackAddedEmbed(track as Track, player.queue.tracks.length)] });
        } else {
          await loadingMsg.delete().catch(() => null);
        }
      }

      if (!player.playing) {
        await player.play({ paused: false });
      }
    } catch (error) {
      logger.error("Error en !play:", error);
      await loadingMsg.edit({ content: "", embeds: [errorEmbed(`Error al buscar: \`${(error as Error).message}\``)] });
      if (!player.playing && player.queue.tracks.length === 0) {
        await player.destroy().catch(() => null);
      }
    }
  },
};
