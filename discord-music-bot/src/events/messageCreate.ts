import type { Client } from "discord.js";
import { config } from "../config.js";
import { logger } from "../utils/logger.js";
import type { CommandContext } from "../types.js";
import { errorEmbed } from "../utils/embeds.js";

export function registerMessageEvent(client: Client): void {
  client.on("messageCreate", async (message) => {
    if (message.author.bot) return;
    if (!message.guild) return;

    const prefix = config.discord.prefix;
    if (!message.content.startsWith(prefix)) return;

    const args = message.content.slice(prefix.length).trim().split(/\s+/);
    const commandName = args.shift()?.toLowerCase();
    if (!commandName) return;

    const command =
      client.commands.get(commandName) ??
      [...client.commands.values()].find((c) => c.aliases?.includes(commandName));

    if (!command) return;

    // Check voice channel requirements
    if (command.requiresVoice) {
      const member = message.member;
      if (!member?.voice?.channel) {
        await message.reply({ embeds: [errorEmbed("Debes estar en un canal de voz primero.")] });
        return;
      }
    }

    // Get or check existing player
    let player = client.lavalink.getPlayer(message.guild.id);
    if (command.requiresPlayer && !player) {
      await message.reply({ embeds: [errorEmbed("No hay nada reproduciéndose ahora.")] });
      return;
    }

    const ctx: CommandContext = {
      client,
      message,
      args,
      player: player ?? undefined,
    };

    try {
      await command.execute(ctx);
    } catch (error) {
      logger.error(`Error en comando "${commandName}":`, error);
      await message
        .reply({ embeds: [errorEmbed(`Error inesperado: \`${(error as Error).message}\``)] })
        .catch(() => null);
    }
  });
}
