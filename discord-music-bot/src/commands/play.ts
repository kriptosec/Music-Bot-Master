import type { Track } from "lavalink-client";
import type { Command, CommandContext } from "../types.js";
import { errorEmbed, trackAddedEmbed, playlistAddedEmbed } from "../utils/embeds.js";
import { cleanQuery, parseLoadError } from "../utils/format.js";
import { logger } from "../utils/logger.js";
import { ytdlpSearch, isYouTubeQuery } from "../utils/ytdlp.js";

// ── Utility: patch a Lavalink HTTP track with YouTube metadata ────────────────
function applyYtMeta(
  httpTrack: Track,
  meta: { title: string; author: string; uri: string; thumbnail: string; duration: number }
): Track {
  httpTrack.info.title     = meta.title;
  httpTrack.info.author    = meta.author;
  httpTrack.info.uri       = meta.uri;
  httpTrack.info.artworkUrl = meta.thumbnail;
  httpTrack.info.duration  = meta.duration;
  httpTrack.info.isStream  = false;
  return httpTrack;
}

export const play: Command = {
  name: "play",
  aliases: ["p", "tocar", "reproducir"],
  description: "Reproduce una canción o la agrega a la cola. Soporta YouTube, Spotify y SoundCloud.",
  usage: "<canción o URL>",
  category: "music",
  requiresVoice: true,

  async execute({ client, message, args }: CommandContext) {
    if (!args.length) {
      await message.reply({ embeds: [errorEmbed("Debes especificar una canción o URL.")] });
      return;
    }

    const { query, stripped } = cleanQuery(args.join(" "));
    const guild  = message.guild!;
    const member = message.member!;
    const voiceChannel = member.voice.channel!;

    let player = client.lavalink.getPlayer(guild.id);

    if (!player) {
      try {
        player = await client.lavalink.createPlayer({
          guildId:       guild.id,
          voiceChannelId: voiceChannel.id,
          textChannelId:  message.channel.id,
          selfDeaf:  true,
          selfMute:  false,
          volume:    80,
          instaUpdateFiltersFix: true,
          applyVolumeAsFilter:   false,
        });
      } catch {
        await message.reply({ embeds: [errorEmbed("⏳ Lavalink aún está iniciando. Espera unos segundos e intentá de nuevo.")] });
        return;
      }
    }

    if (!player.connected) await player.connect();
    player.textChannelId = message.channel.id;

    const loadingMsg = await message.reply({
      content: stripped
        ? "🔍 Buscando... *(era una radio/mix de YouTube, reproduciré solo el video)*"
        : "🔍 Buscando...",
    });

    try {
      // ── YouTube path: plugin first (OAuth, fast), yt-dlp as fallback ────────
      if (isYouTubeQuery(query)) {
        // 1. Try the Lavalink YouTube plugin (OAuth — instant when authenticated)
        const ytQuery = query.startsWith("http") ? query : `ytsearch:${query}`;
        logger.debug(`[play] Lavalink plugin search: ${ytQuery}`);
        const pluginResult = await player.search({ query: ytQuery }, message.author);

        if (pluginResult.loadType !== "empty" && pluginResult.loadType !== "error" && pluginResult.tracks.length) {
          const track = pluginResult.tracks[0] as Track;
          await player.queue.add(track);
          if (player.playing) {
            await loadingMsg.edit({ content: "", embeds: [trackAddedEmbed(track, player.queue.tracks.length)] });
          } else {
            await loadingMsg.delete().catch(() => null);
          }
          if (!player.playing) await player.play({ paused: false });
          return;
        }

        // 2. Plugin failed — fall back to yt-dlp (slower but uses cookies auth)
        logger.warn("[play] Lavalink plugin falló para YouTube, usando yt-dlp como fallback...");
        const info = await ytdlpSearch(query);

        if (!info) {
          await loadingMsg.edit({ content: "", embeds: [errorEmbed("🔍 **No se encontraron resultados.** Intentá con otro nombre.")] });
          if (!player.playing && !player.queue.tracks.length) await player.destroy();
          return;
        }

        const audioIdentifier = info.audioUrl || info.proxyUrl;

        if (!audioIdentifier) {
          await loadingMsg.edit({ content: "", embeds: [errorEmbed("❌ yt-dlp no pudo obtener la URL de audio.")] });
          if (!player.playing && !player.queue.tracks.length) await player.destroy();
          return;
        }

        const httpResult = await player.search({ query: audioIdentifier }, message.author);

        if (httpResult.loadType === "empty" || httpResult.loadType === "error") {
          const rawErr = (httpResult as { exception?: { message?: string } }).exception?.message;
          await loadingMsg.edit({ content: "", embeds: [errorEmbed(parseLoadError(rawErr ?? "No se pudo cargar el audio de YouTube."))] });
          if (!player.playing && !player.queue.tracks.length) await player.destroy();
          return;
        }

        const track = applyYtMeta(httpResult.tracks[0] as Track, info);
        await player.queue.add(track);

        if (player.playing) {
          await loadingMsg.edit({ content: "", embeds: [trackAddedEmbed(track, player.queue.tracks.length)] });
        } else {
          await loadingMsg.delete().catch(() => null);
        }

        if (!player.playing) await player.play({ paused: false });
        return;
      }

      // ── SoundCloud / Spotify / direct URL path: use Lavalink directly ───────
      const result = await player.search(
        { query, source: query.startsWith("http") ? undefined : "scsearch" },
        message.author
      );

      if (result.loadType === "empty") {
        await loadingMsg.edit({ content: "", embeds: [errorEmbed(`🔍 **No se encontraron resultados** para: \`${query}\``)] });
        if (!player.playing && !player.queue.tracks.length) await player.destroy();
        return;
      }

      if (result.loadType === "error") {
        const errMsg = (result as { exception?: { message?: string } }).exception?.message;
        await loadingMsg.edit({ content: "", embeds: [errorEmbed(parseLoadError(errMsg))] });
        if (!player.playing && !player.queue.tracks.length) await player.destroy();
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

      if (!player.playing) await player.play({ paused: false });

    } catch (error) {
      logger.error("Error en !play:", error);
      await loadingMsg.edit({ content: "", embeds: [errorEmbed(parseLoadError((error as Error).message))] });
      if (!player.playing && !player.queue.tracks.length) {
        await player.destroy().catch(() => null);
      }
    }
  },
};
