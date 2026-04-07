import { EmbedBuilder } from "discord.js";
import type { Command, CommandContext } from "../types.js";
import { config } from "../config.js";

const COMMANDS_BY_CATEGORY: Record<string, Array<{ cmd: string; desc: string }>> = {
  "▶️ Reproducción": [
    { cmd: "play <canción>", desc: "Reproduce o agrega a la cola" },
    { cmd: "search <canción>", desc: "Busca y elige una canción" },
    { cmd: "pause", desc: "Pausa la reproducción" },
    { cmd: "resume", desc: "Reanuda la reproducción" },
    { cmd: "stop", desc: "Detiene y limpia la cola" },
    { cmd: "skip", desc: "Salta la canción actual" },
    { cmd: "skipto <n>", desc: "Salta a posición en cola" },
    { cmd: "seek <tiempo>", desc: "Salta a un tiempo (ej: `1:30`)" },
    { cmd: "nowplaying", desc: "Muestra la canción actual" },
    { cmd: "disconnect", desc: "Desconecta el bot" },
  ],
  "📋 Cola": [
    { cmd: "queue [página]", desc: "Ver la cola de reproducción" },
    { cmd: "remove <n>", desc: "Eliminar canción de la cola" },
    { cmd: "move <de> <a>", desc: "Mover canción en la cola" },
    { cmd: "shuffle", desc: "Mezclar aleatoriamente" },
    { cmd: "clear", desc: "Limpiar toda la cola" },
    { cmd: "loop <track|queue|off>", desc: "Modo de repetición" },
  ],
  "🎚️ Audio": [
    { cmd: "volume <0-200>", desc: "Ajustar volumen" },
    { cmd: "filters [preset]", desc: "Filtros de audio (bass, night, slow, 8d...)" },
  ],
};

export const help: Command = {
  name: "help",
  aliases: ["h", "ayuda", "comandos", "commands"],
  description: "Muestra todos los comandos disponibles.",
  category: "info",

  async execute({ client, message, args }) {
    const prefix = config.discord.prefix;

    if (args[0]) {
      const cmdName = args[0].toLowerCase();
      const cmd =
        client.commands.get(cmdName) ??
        [...client.commands.values()].find((c) => c.aliases?.includes(cmdName));

      if (!cmd) {
        await message.reply({ content: `❌ Comando \`${cmdName}\` no encontrado.` });
        return;
      }

      const embed = new EmbedBuilder()
        .setColor(0x5865f2)
        .setTitle(`📖 Ayuda: \`${prefix}${cmd.name}\``)
        .setDescription(cmd.description);

      if (cmd.usage) embed.addFields({ name: "Uso", value: `\`${prefix}${cmd.name} ${cmd.usage}\``, inline: false });
      if (cmd.aliases?.length) embed.addFields({ name: "Aliases", value: cmd.aliases.map((a) => `\`${prefix}${a}\``).join(", "), inline: false });

      await message.reply({ embeds: [embed] });
      return;
    }

    const embed = new EmbedBuilder()
      .setColor(0x7289da)
      .setTitle("🎵 Music Bot — Comandos")
      .setDescription(`Prefijo: \`${prefix}\` | Ayuda de un comando: \`${prefix}help <comando>\`\n`);

    for (const [category, cmds] of Object.entries(COMMANDS_BY_CATEGORY)) {
      embed.addFields({
        name: category,
        value: cmds.map((c) => `\`${prefix}${c.cmd}\` — ${c.desc}`).join("\n"),
        inline: false,
      });
    }

    embed.addFields({
      name: "🎯 Fuentes soportadas",
      value: "🔴 YouTube • 🟢 Spotify • 🟠 SoundCloud • URLs directas",
      inline: false,
    });

    embed.setFooter({ text: "Music Bot v2.0 | discord.js + lavalink-client" });

    await message.reply({ embeds: [embed] });
  },
};

export const ping: Command = {
  name: "ping",
  aliases: [],
  description: "Muestra la latencia del bot.",
  category: "info",

  async execute({ client, message }) {
    const sent = await message.reply({ content: "🏓 Calculando..." });
    const latency = sent.createdTimestamp - message.createdTimestamp;
    const wsLatency = Math.round(client.ws.ping);

    const embed = new EmbedBuilder()
      .setColor(latency < 100 ? 0x43b581 : latency < 300 ? 0xfaa61a : 0xf04747)
      .setTitle("🏓 Pong!")
      .addFields(
        { name: "Mensaje", value: `\`${latency}ms\``, inline: true },
        { name: "WebSocket", value: `\`${wsLatency}ms\``, inline: true }
      );

    await sent.edit({ content: "", embeds: [embed] });
  },
};

export const info: Command = {
  name: "info",
  aliases: ["about", "acerca"],
  description: "Muestra información del bot.",
  category: "info",

  async execute({ client, message }) {
    const guilds = client.guilds.cache.size;
    const activePlayers = client.lavalink.players.size;
    const memMB = (process.memoryUsage().heapUsed / 1024 / 1024).toFixed(1);
    const uptime = process.uptime();
    const uptimeStr = `${Math.floor(uptime / 3600)}h ${Math.floor((uptime % 3600) / 60)}m ${Math.floor(uptime % 60)}s`;

    const embed = new EmbedBuilder()
      .setColor(0x7289da)
      .setTitle(`ℹ️ ${client.user?.username ?? "Music Bot"}`)
      .addFields(
        { name: "Versión", value: "`2.0.0`", inline: true },
        { name: "discord.js", value: "`v14`", inline: true },
        { name: "Audio", value: "`Lavalink v4`", inline: true },
        { name: "Servidores", value: `\`${guilds}\``, inline: true },
        { name: "Players activos", value: `\`${activePlayers}\``, inline: true },
        { name: "Memoria", value: `\`${memMB} MB\``, inline: true },
        { name: "Uptime", value: `\`${uptimeStr}\``, inline: true },
        { name: "Node.js", value: `\`${process.version}\``, inline: true },
        { name: "Prefijo", value: `\`${config.discord.prefix}\``, inline: true }
      );

    if (client.user?.avatarURL()) embed.setThumbnail(client.user.avatarURL());

    await message.reply({ embeds: [embed] });
  },
};
