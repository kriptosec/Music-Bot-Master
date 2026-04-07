import type { Command, CommandContext } from "../types.js";
import { errorEmbed, successEmbed } from "../utils/embeds.js";

export const skip: Command = {
  name: "skip",
  aliases: ["s", "saltar", "siguiente"],
  description: "Salta la canción actual.",
  category: "music",
  requiresPlayer: true,
  requiresVoice: true,
  async execute({ client, message }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    if (!player.playing && !player.paused) {
      await message.reply({ embeds: [errorEmbed("No hay nada reproduciéndose.")] });
      return;
    }
    const current = player.queue.current;
    await player.skip();
    await message.reply({ embeds: [successEmbed(`Saltado: **${current?.info.title ?? "canción desconocida"}**`)] });
  },
};

export const skipto: Command = {
  name: "skipto",
  aliases: ["st"],
  description: "Salta a una posición específica en la cola.",
  usage: "<posición>",
  category: "music",
  requiresPlayer: true,
  requiresVoice: true,
  async execute({ client, message, args }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    const pos = parseInt(args[0]);
    if (isNaN(pos) || pos < 1) {
      await message.reply({ embeds: [errorEmbed("Especifica una posición válida.")] });
      return;
    }
    const qSize = player.queue.tracks.length;
    if (pos > qSize) {
      await message.reply({ embeds: [errorEmbed(`La cola tiene \`${qSize}\` canciones.`)] });
      return;
    }
    // Remove tracks before position
    player.queue.tracks.splice(0, pos - 1);
    await player.skip();
    await message.reply({ embeds: [successEmbed(`Saltando a la posición \`${pos}\` en la cola.`)] });
  },
};

export const pause: Command = {
  name: "pause",
  aliases: ["pausar"],
  description: "Pausa la reproducción.",
  category: "music",
  requiresPlayer: true,
  requiresVoice: true,
  async execute({ client, message }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    if (player.paused) {
      await message.reply({ embeds: [errorEmbed("Ya está pausado. Usa `!resume` para reanudar.")] });
      return;
    }
    await player.pause();
    await message.reply({ embeds: [successEmbed("⏸️ Pausado.")] });
  },
};

export const resume: Command = {
  name: "resume",
  aliases: ["reanudar", "continuar"],
  description: "Reanuda la reproducción.",
  category: "music",
  requiresPlayer: true,
  requiresVoice: true,
  async execute({ client, message }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    if (!player.paused) {
      await message.reply({ embeds: [errorEmbed("No está pausado.")] });
      return;
    }
    await player.resume();
    await message.reply({ embeds: [successEmbed("▶️ Reanudado.")] });
  },
};

export const stop: Command = {
  name: "stop",
  aliases: ["detener", "parar"],
  description: "Detiene la reproducción y limpia la cola.",
  category: "music",
  requiresPlayer: true,
  requiresVoice: true,
  async execute({ client, message }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    player.queue.tracks.splice(0);
    await player.stopPlaying(true, false);
    await message.reply({ embeds: [successEmbed("⏹️ Reproducción detenida y cola limpiada.")] });
  },
};

export const disconnect: Command = {
  name: "disconnect",
  aliases: ["dc", "salir", "leave", "desconectar"],
  description: "Desconecta el bot del canal de voz.",
  category: "music",
  requiresPlayer: true,
  requiresVoice: true,
  async execute({ client, message }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    await player.destroy();
    await message.reply({ embeds: [successEmbed("👋 Desconectado.")] });
  },
};

export const seek: Command = {
  name: "seek",
  aliases: ["ir"],
  description: "Salta a una posición específica en la canción. Formato: segundos o MM:SS.",
  usage: "<tiempo>",
  category: "music",
  requiresPlayer: true,
  requiresVoice: true,
  async execute({ client, message, args }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    if (!player.queue.current) {
      await message.reply({ embeds: [errorEmbed("No hay nada reproduciéndose.")] });
      return;
    }
    if (player.queue.current.info.isStream) {
      await message.reply({ embeds: [errorEmbed("No se puede hacer seek en transmisiones en vivo.")] });
      return;
    }

    const input = args[0];
    if (!input) {
      await message.reply({ embeds: [errorEmbed("Especifica un tiempo. Ej: `1:30` o `90`.")] });
      return;
    }

    let ms: number;
    if (input.includes(":")) {
      const parts = input.split(":").map(Number);
      if (parts.some(isNaN)) {
        await message.reply({ embeds: [errorEmbed("Formato inválido. Usa `MM:SS` o `HH:MM:SS`.")] });
        return;
      }
      if (parts.length === 2) ms = (parts[0] * 60 + parts[1]) * 1000;
      else ms = (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000;
    } else {
      ms = parseInt(input) * 1000;
    }

    if (isNaN(ms) || ms < 0) {
      await message.reply({ embeds: [errorEmbed("Tiempo inválido.")] });
      return;
    }

    const duration = player.queue.current.info.duration ?? 0;
    if (ms > duration) {
      await message.reply({ embeds: [errorEmbed(`Fuera de rango. La canción dura \`${Math.floor(duration / 1000)}\` segundos.`)] });
      return;
    }

    await player.seek(ms);
    const { formatDuration } = await import("../utils/format.js");
    await message.reply({ embeds: [successEmbed(`⏩ Saltando a \`${formatDuration(ms)}\``)] });
  },
};
