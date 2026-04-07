import { EmbedBuilder } from "discord.js";
import type { Command, CommandContext } from "../types.js";
import { errorEmbed } from "../utils/embeds.js";
import { formatDuration, getSourceEmoji } from "../utils/format.js";
import { logger } from "../utils/logger.js";

export const search: Command = {
  name: "search",
  aliases: ["buscar", "find"],
  description: "Busca canciones en YouTube y permite elegir cuál reproducir.",
  usage: "<canción>",
  category: "music",
  requiresVoice: true,

  async execute({ client, message, args }) {
    if (!args.length) {
      await message.reply({ embeds: [errorEmbed("Debes especificar qué buscar.")] });
      return;
    }

    const query = args.join(" ");
    const loadingMsg = await message.reply({ content: "🔍 Buscando..." });

    let fakePlayer = client.lavalink.getPlayer(message.guild!.id);
    if (!fakePlayer) {
      fakePlayer = await client.lavalink.createPlayer({
        guildId: message.guild!.id,
        voiceChannelId: message.member!.voice.channel!.id,
        textChannelId: message.channel.id,
        selfDeaf: true,
        volume: 80,
        instaUpdateFiltersFix: true,
        applyVolumeAsFilter: false,
      });
    }

    try {
      const result = await fakePlayer.search({ query, source: "ytsearch" }, message.author);

      if (!result.tracks.length) {
        await loadingMsg.edit({ content: "", embeds: [errorEmbed(`Sin resultados para: \`${query}\``)] });
        if (!fakePlayer.playing && fakePlayer.queue.tracks.length === 0) await fakePlayer.destroy().catch(() => null);
        return;
      }

      const tracks = result.tracks.slice(0, 5);
      const embed = new EmbedBuilder()
        .setColor(0x5865f2)
        .setTitle(`🔍 Resultados para: ${query.slice(0, 50)}`)
        .setDescription(
          tracks.map((t, i) =>
            `\`${i + 1}.\` ${getSourceEmoji(t.info.uri)} **${t.info.title}** — \`${t.info.author}\` — \`${formatDuration(t.info.duration ?? 0)}\``
          ).join("\n")
        )
        .setFooter({ text: "Responde con el número (1-5) o 'cancelar'" });

      await loadingMsg.edit({ content: "", embeds: [embed] });

      const filter = (m: import("discord.js").Message) =>
        m.author.id === message.author.id &&
        m.channel.id === message.channel.id &&
        (/^[1-5]$/.test(m.content) || ["cancelar", "cancel"].includes(m.content.toLowerCase()));

      const collected = await message.channel
        .awaitMessages({ filter, max: 1, time: 30_000 })
        .catch(() => null);

      if (!collected || collected.size === 0) {
        await loadingMsg.edit({ content: "⏰ Tiempo agotado.", embeds: [] });
        if (!fakePlayer.playing && fakePlayer.queue.tracks.length === 0) await fakePlayer.destroy().catch(() => null);
        return;
      }

      const reply = collected.first()!;
      await reply.delete().catch(() => null);

      if (["cancelar", "cancel"].includes(reply.content.toLowerCase())) {
        await loadingMsg.edit({ content: "❌ Búsqueda cancelada.", embeds: [] });
        if (!fakePlayer.playing && fakePlayer.queue.tracks.length === 0) await fakePlayer.destroy().catch(() => null);
        return;
      }

      const idx = parseInt(reply.content) - 1;
      const selected = tracks[idx];

      if (!fakePlayer.connected) await fakePlayer.connect();
      fakePlayer.textChannelId = message.channel.id;

      await fakePlayer.queue.add(selected);
      if (!fakePlayer.playing) {
        await fakePlayer.play({ paused: false });
        await loadingMsg.delete().catch(() => null);
      } else {
        const { trackAddedEmbed } = await import("../utils/embeds.js");
        await loadingMsg.edit({ content: "", embeds: [trackAddedEmbed(selected, fakePlayer.queue.tracks.length)] });
      }
    } catch (error) {
      logger.error("Error en !search:", error);
      await loadingMsg.edit({ content: "", embeds: [errorEmbed(`Error al buscar: \`${(error as Error).message}\``)] });
    }
  },
};
