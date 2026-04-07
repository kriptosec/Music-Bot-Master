import { EmbedBuilder } from "discord.js";
import type { Command } from "../types.js";
import { errorEmbed, successEmbed } from "../utils/embeds.js";
import { logger } from "../utils/logger.js";

export const volume: Command = {
  name: "volume",
  aliases: ["vol", "volumen"],
  description: "Ajusta el volumen del bot (0-200).",
  usage: "<0-200>",
  category: "audio",
  requiresPlayer: true,
  requiresVoice: true,

  async execute({ client, message, args }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;

    if (!args[0]) {
      const emoji = player.volume === 0 ? "🔇" : player.volume < 50 ? "🔉" : "🔊";
      await message.reply({ embeds: [errorEmbed(`Volumen actual: ${emoji} \`${player.volume}%\`. Especifica un valor (0-200).`)] });
      return;
    }

    const vol = parseInt(args[0]);
    if (isNaN(vol) || vol < 0 || vol > 200) {
      await message.reply({ embeds: [errorEmbed("El volumen debe estar entre `0` y `200`.")] });
      return;
    }

    await player.setVolume(vol);
    const emoji = vol === 0 ? "🔇" : vol < 50 ? "🔉" : "🔊";
    await message.reply({ embeds: [successEmbed(`${emoji} Volumen ajustado a \`${vol}%\``)] });
  },
};

const FILTER_PRESETS: Record<string, { name: string; description: string }> = {
  bass: { name: "Bass Boost", description: "Refuerzo de graves potente" },
  night: { name: "Nightcore", description: "Velocidad y pitch aumentados" },
  slow: { name: "Slowed", description: "Velocidad y pitch reducidos" },
  pop: { name: "Pop", description: "Ecualizador optimizado para pop" },
  rock: { name: "Rock", description: "Ecualizador optimizado para rock" },
  "8d": { name: "8D Audio", description: "Efecto de audio 8D (rotación)" },
  soft: { name: "Soft", description: "Ecualizador suave y tranquilo" },
  clear: { name: "Sin filtros", description: "Elimina todos los filtros" },
};

export const filters: Command = {
  name: "filters",
  aliases: ["filtros", "efectos", "filter"],
  description: "Aplica filtros de audio. Usa sin argumentos para ver opciones.",
  usage: "[preset]",
  category: "audio",
  requiresPlayer: true,
  requiresVoice: true,

  async execute({ client, message, args }) {
    const player = client.lavalink.getPlayer(message.guild!.id)!;
    const preset = (args[0] ?? "").toLowerCase();

    if (!preset || preset === "help" || preset === "ayuda") {
      const embed = new EmbedBuilder()
        .setColor(0x5865f2)
        .setTitle("🎚️ Filtros de Audio")
        .setDescription("Usa `!filters <nombre>` para aplicar un filtro:")
        .addFields(
          Object.entries(FILTER_PRESETS).map(([key, val]) => ({
            name: `\`${key}\``,
            value: val.description,
            inline: true,
          }))
        );
      await message.reply({ embeds: [embed] });
      return;
    }

    if (!FILTER_PRESETS[preset]) {
      await message.reply({ embeds: [errorEmbed(`Filtro desconocido: \`${preset}\`. Usa \`!filters\` para ver opciones.`)] });
      return;
    }

    try {
      const fm = player.filterManager;

      if (preset === "clear") {
        await fm.resetFilters();
        await message.reply({ embeds: [successEmbed("✅ Filtros eliminados.")] });
        return;
      }

      if (preset === "bass") {
        // setEQ reemplaza a setEqualizer en lavalink-client v2.9.x
        await fm.setEQ([
          { band: 0, gain: 0.3 }, { band: 1, gain: 0.25 },
          { band: 2, gain: 0.2 }, { band: 3, gain: 0.1 },
        ]);
      } else if (preset === "night") {
        // setSpeed/setPitch reemplazan a setTimescale en lavalink-client v2.9.x
        await fm.setSpeed(1.25);
        await fm.setPitch(1.15);
      } else if (preset === "slow") {
        await fm.setSpeed(0.75);
        await fm.setPitch(0.9);
      } else if (preset === "pop") {
        await fm.setEQ([
          { band: 0, gain: -0.05 }, { band: 1, gain: 0.15 },
          { band: 2, gain: 0.2 }, { band: 3, gain: 0.1 }, { band: 4, gain: 0.05 },
        ]);
      } else if (preset === "rock") {
        await fm.setEQ([
          { band: 0, gain: 0.3 }, { band: 1, gain: 0.2 },
          { band: 5, gain: 0.1 }, { band: 6, gain: 0.2 }, { band: 7, gain: 0.3 },
        ]);
      } else if (preset === "8d") {
        // toggleRotation reemplaza a setRotation en lavalink-client v2.9.x
        await fm.toggleRotation(0.2);
      } else if (preset === "soft") {
        await fm.setEQ([
          { band: 0, gain: 0 }, { band: 1, gain: 0 },
          { band: 2, gain: 0.1 }, { band: 3, gain: 0.2 },
          { band: 4, gain: 0.3 }, { band: 5, gain: 0.2 },
        ]);
      }

      const info = FILTER_PRESETS[preset];
      await message.reply({ embeds: [successEmbed(`🎚️ Filtro **${info.name}** aplicado.`)] });
    } catch (error) {
      logger.error("Error al aplicar filtro:", error);
      await message.reply({ embeds: [errorEmbed(`Error al aplicar filtro: \`${(error as Error).message}\``)] });
    }
  },
};
