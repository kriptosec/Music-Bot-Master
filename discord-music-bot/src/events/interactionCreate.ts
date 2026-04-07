import {
  ChatInputCommandInteraction,
  Client,
  EmbedBuilder,
  GuildMember,
} from "discord.js";
import type { Track } from "lavalink-client";
import { logger } from "../utils/logger.js";
import {
  errorEmbed,
  successEmbed,
  nowPlayingEmbed,
  trackAddedEmbed,
  playlistAddedEmbed,
} from "../utils/embeds.js";
import { formatDuration, chunkArray, getSourceEmoji, truncate, cleanQuery, parseLoadError } from "../utils/format.js";
import { ytdlpSearch, isYouTubeQuery } from "../utils/ytdlp.js";

// ─── Helper: patch HTTP track with YouTube metadata ───────────────────────────
function applyYtMeta(
  httpTrack: Track,
  meta: { title: string; author: string; uri: string; thumbnail: string; duration: number }
): Track {
  httpTrack.info.title      = meta.title;
  httpTrack.info.author     = meta.author;
  httpTrack.info.uri        = meta.uri;
  httpTrack.info.artworkUrl = meta.thumbnail;
  httpTrack.info.duration   = meta.duration;
  httpTrack.info.isStream   = false;
  return httpTrack;
}

// ─── Helper: reply to an interaction (deferred) ───────────────────────────────
async function reply(
  interaction: ChatInputCommandInteraction,
  options: Parameters<ChatInputCommandInteraction["editReply"]>[0]
) {
  return interaction.editReply(options);
}

// ─── Helper: check voice + player prerequisites ───────────────────────────────
async function checkVoice(interaction: ChatInputCommandInteraction): Promise<boolean> {
  const member = interaction.member as GuildMember;
  if (!member.voice.channel) {
    await reply(interaction, { embeds: [errorEmbed("Debes estar en un canal de voz.")] });
    return false;
  }
  return true;
}

// ─── Slash command handlers ───────────────────────────────────────────────────

async function handlePlay(interaction: ChatInputCommandInteraction, client: Client) {
  if (!await checkVoice(interaction)) return;

  const { query, stripped } = cleanQuery(interaction.options.getString("cancion", true));
  const guild = interaction.guild!;
  const member = interaction.member as GuildMember;
  const voiceChannel = member.voice.channel!;

  let player = client.lavalink.getPlayer(guild.id);
  if (!player) {
    try {
      player = await client.lavalink.createPlayer({
        guildId: guild.id,
        voiceChannelId: voiceChannel.id,
        textChannelId: interaction.channelId,
        selfDeaf: true,
        selfMute: false,
        volume: 80,
        instaUpdateFiltersFix: true,
        applyVolumeAsFilter: false,
      });
    } catch {
      await reply(interaction, {
        embeds: [errorEmbed("⏳ Lavalink aún está iniciando. Espera unos segundos e intentá de nuevo.")],
      });
      return;
    }
  }

  if (!player.connected) await player.connect();
  player.textChannelId = interaction.channelId;

  await reply(interaction, {
    content: stripped
      ? "🔍 Buscando... *(era una radio/mix de YouTube, reproduciré solo el video)*"
      : "🔍 Buscando...",
  });

  try {
    // ── YouTube path: yt-dlp audio URL ───────────────────────────────────────
    if (isYouTubeQuery(query)) {
      logger.debug(`[/play] yt-dlp search: ${query}`);
      const info = await ytdlpSearch(query);

      if (!info) {
        await reply(interaction, { content: "", embeds: [errorEmbed("🔍 **No se encontraron resultados.** Intentá con otro nombre.")] });
        if (!player.playing && player.queue.tracks.length === 0) await player.destroy();
        return;
      }

      const audioIdentifier = info.proxyUrl || info.audioUrl;
      if (!audioIdentifier) {
        await reply(interaction, { content: "", embeds: [errorEmbed("❌ yt-dlp no pudo obtener la URL de audio.")] });
        if (!player.playing && player.queue.tracks.length === 0) await player.destroy();
        return;
      }

      const httpResult = await player.search({ query: audioIdentifier }, interaction.user);

      if (httpResult.loadType === "empty" || httpResult.loadType === "error") {
        const rawErr = (httpResult as { exception?: { message?: string } }).exception?.message;
        await reply(interaction, { content: "", embeds: [errorEmbed(parseLoadError(rawErr ?? "No se pudo cargar el audio de YouTube."))] });
        if (!player.playing && player.queue.tracks.length === 0) await player.destroy();
        return;
      }

      const track = applyYtMeta(httpResult.tracks[0] as Track, info);
      await player.queue.add(track);

      if (player.playing) {
        await reply(interaction, { content: "", embeds: [trackAddedEmbed(track, player.queue.tracks.length)] });
      } else {
        await reply(interaction, { content: "▶️ Reproduciendo..." });
      }

      if (!player.playing) await player.play({ paused: false });
      return;
    }

    // ── SoundCloud / Spotify / direct URL ────────────────────────────────────
    const result = await player.search(
      { query, source: query.startsWith("http") ? undefined : "scsearch" },
      interaction.user
    );

    if (result.loadType === "empty") {
      await reply(interaction, { content: "", embeds: [errorEmbed(`🔍 **No se encontraron resultados** para: \`${query}\``)] });
      if (!player.playing && player.queue.tracks.length === 0) await player.destroy();
      return;
    }

    if (result.loadType === "error") {
      const errMsg = (result as { exception?: { message?: string } }).exception?.message;
      await reply(interaction, { content: "", embeds: [errorEmbed(parseLoadError(errMsg))] });
      if (!player.playing && player.queue.tracks.length === 0) await player.destroy();
      return;
    }

    if (result.loadType === "playlist") {
      await player.queue.add(result.tracks);
      await reply(interaction, { content: "", embeds: [playlistAddedEmbed(result.playlist?.name ?? "Lista desconocida", result.tracks.length)] });
    } else {
      const track = result.tracks[0];
      await player.queue.add(track);
      if (player.playing) {
        await reply(interaction, { content: "", embeds: [trackAddedEmbed(track as Track, player.queue.tracks.length)] });
      } else {
        await reply(interaction, { content: "▶️ Reproduciendo..." });
      }
    }

    if (!player.playing) await player.play({ paused: false });
  } catch (err) {
    logger.error("Error en /play:", err);
    await reply(interaction, { content: "", embeds: [errorEmbed(parseLoadError((err as Error).message))] });
    if (!player.playing && player.queue.tracks.length === 0) await player.destroy().catch(() => null);
  }
}

async function handleSkip(interaction: ChatInputCommandInteraction, client: Client) {
  if (!await checkVoice(interaction)) return;
  const player = client.lavalink.getPlayer(interaction.guild!.id);
  if (!player || (!player.playing && !player.paused)) {
    await reply(interaction, { embeds: [errorEmbed("No hay nada reproduciéndose.")] });
    return;
  }
  const current = player.queue.current;
  await player.skip();
  await reply(interaction, { embeds: [successEmbed(`Saltado: **${current?.info.title ?? "canción desconocida"}**`)] });
}

async function handlePause(interaction: ChatInputCommandInteraction, client: Client) {
  if (!await checkVoice(interaction)) return;
  const player = client.lavalink.getPlayer(interaction.guild!.id);
  if (!player) {
    await reply(interaction, { embeds: [errorEmbed("No hay nada reproduciéndose.")] });
    return;
  }
  if (player.paused) {
    await player.resume();
    await reply(interaction, { embeds: [successEmbed("▶️ Reanudado.")] });
  } else {
    await player.pause();
    await reply(interaction, { embeds: [successEmbed("⏸️ Pausado.")] });
  }
}

async function handleStop(interaction: ChatInputCommandInteraction, client: Client) {
  if (!await checkVoice(interaction)) return;
  const player = client.lavalink.getPlayer(interaction.guild!.id);
  if (!player) {
    await reply(interaction, { embeds: [errorEmbed("No hay nada reproduciéndose.")] });
    return;
  }
  player.queue.tracks.splice(0);
  await player.stopPlaying(true, false);
  await reply(interaction, { embeds: [successEmbed("⏹️ Reproducción detenida y cola limpiada.")] });
}

async function handleNowPlaying(interaction: ChatInputCommandInteraction, client: Client) {
  const player = client.lavalink.getPlayer(interaction.guild!.id);
  if (!player?.queue.current) {
    await reply(interaction, { embeds: [errorEmbed("No hay nada reproduciéndose.")] });
    return;
  }
  const track = player.queue.current as Track;
  const loopLabel = player.repeatMode === "track" ? "Canción" : player.repeatMode === "queue" ? "Cola" : "Off";
  await reply(interaction, { embeds: [nowPlayingEmbed(track, player.position, player.volume, player.queue.tracks.length, loopLabel)] });
}

async function handleQueue(interaction: ChatInputCommandInteraction, client: Client) {
  const player = client.lavalink.getPlayer(interaction.guild!.id);
  if (!player || (!player.queue.current && player.queue.tracks.length === 0)) {
    await reply(interaction, { embeds: [errorEmbed("La cola está vacía.")] });
    return;
  }

  const tracksPerPage = 10;
  const tracks = player.queue.tracks;
  const pages = chunkArray(tracks, tracksPerPage);
  const totalPages = Math.max(1, pages.length);
  const requestedPage = interaction.options.getInteger("pagina") ?? 1;
  const page = Math.max(1, Math.min(requestedPage, totalPages));

  const embed = new EmbedBuilder().setColor(0x23272a).setTitle("📋 Cola de Reproducción");

  if (player.queue.current) {
    const cur = player.queue.current;
    embed.addFields({
      name: "▶️ Reproduciendo ahora",
      value: `${getSourceEmoji(cur.info.uri)} **[${truncate(cur.info.title, 60)}](${cur.info.uri ?? ""})**\n👤 ${cur.info.author} • ⏱️ \`${formatDuration(player.position)} / ${formatDuration(cur.info.duration ?? 0)}\``,
      inline: false,
    });
  }

  if (tracks.length > 0) {
    const currentPageTracks = pages[page - 1] ?? [];
    const startIndex = (page - 1) * tracksPerPage;
    const entries = currentPageTracks.map((t, i) =>
      `\`${startIndex + i + 1}.\` ${getSourceEmoji(t.info.uri)} **${truncate(t.info.title, 55)}**\n     👤 ${t.info.author} • ⏱️ \`${formatDuration(t.info.duration ?? 0)}\``
    );
    const totalDuration = tracks.reduce((sum, t) => sum + (t.info.duration ?? 0), 0);
    const loopMode = player.repeatMode === "track" ? "🔁 Canción" : player.repeatMode === "queue" ? "🔁 Cola" : "❌";
    embed.addFields({ name: `📝 Cola (${tracks.length} canciones)`, value: entries.join("\n") || "—", inline: false });
    embed.setFooter({ text: `Página ${page}/${totalPages} • Duración total: ${formatDuration(totalDuration)} • Loop: ${loopMode}` });
  } else {
    embed.addFields({ name: "📝 Cola", value: "La cola está vacía.", inline: false });
  }

  await reply(interaction, { embeds: [embed] });
}

async function handleVolume(interaction: ChatInputCommandInteraction, client: Client) {
  if (!await checkVoice(interaction)) return;
  const player = client.lavalink.getPlayer(interaction.guild!.id);
  if (!player) {
    await reply(interaction, { embeds: [errorEmbed("No hay nada reproduciéndose.")] });
    return;
  }
  const vol = interaction.options.getInteger("nivel", true);
  if (vol < 0 || vol > 200) {
    await reply(interaction, { embeds: [errorEmbed("El volumen debe estar entre `0` y `200`.")] });
    return;
  }
  await player.setVolume(vol);
  const emoji = vol === 0 ? "🔇" : vol < 50 ? "🔉" : "🔊";
  await reply(interaction, { embeds: [successEmbed(`${emoji} Volumen ajustado a \`${vol}%\``)] });
}

// ─── Register interactionCreate event ────────────────────────────────────────
export function registerInteractionEvent(client: Client): void {
  client.on("interactionCreate", async (interaction) => {
    if (!interaction.isChatInputCommand()) return;
    if (!interaction.guild) {
      await interaction.reply({ content: "Este bot solo funciona en servidores.", ephemeral: true });
      return;
    }

    try {
      await interaction.deferReply();
    } catch {
      return;
    }

    const cmd = interaction.commandName;
    logger.info(`Slash /${cmd} — ${interaction.user.tag} en ${interaction.guild.name}`);

    try {
      switch (cmd) {
        case "play":        await handlePlay(interaction, client); break;
        case "skip":        await handleSkip(interaction, client); break;
        case "pause":       await handlePause(interaction, client); break;
        case "stop":        await handleStop(interaction, client); break;
        case "nowplaying":  await handleNowPlaying(interaction, client); break;
        case "queue":       await handleQueue(interaction, client); break;
        case "volume":      await handleVolume(interaction, client); break;
        default:
          await reply(interaction, { embeds: [errorEmbed(`Comando \`/${cmd}\` no reconocido.`)] });
      }
    } catch (err) {
      logger.error(`Error en slash /${cmd}:`, err);
      await reply(interaction, { embeds: [errorEmbed("Ocurrió un error inesperado.")] }).catch(() => null);
    }
  });
}
