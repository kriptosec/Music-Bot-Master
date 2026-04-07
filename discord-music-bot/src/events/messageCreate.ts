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

    // Log every command attempt
    logger.info(`Comando recibido: "${commandName}" | Servidor: ${message.guild.name} (${message.guild.id}) | Usuario: ${message.author.tag} | Args: [${args.join(", ")}]`);

    const command =
      client.commands.get(commandName) ??
      [...client.commands.values()].find((c) => c.aliases?.includes(commandName));

    if (!command) {
      logger.debug(`Comando desconocido ignorado: "${commandName}"`);
      return;
    }

    logger.debug(`Ejecutando comando: "${command.name}"`);

    // Verificar canal de voz
    if (command.requiresVoice) {
      const member = message.member;
      if (!member?.voice?.channel) {
        logger.info(`"${commandName}" bloqueado — usuario no está en canal de voz`);
        await message.reply({ embeds: [errorEmbed("Debes estar en un canal de voz primero.")] });
        return;
      }
      logger.debug(`Canal de voz OK: ${member.voice.channel.name} (${member.voice.channel.id})`);
    }

    // Verificar player activo
    let player = client.lavalink.getPlayer(message.guild.id);
    if (command.requiresPlayer && !player) {
      logger.info(`"${commandName}" bloqueado — no hay player activo`);
      await message.reply({ embeds: [errorEmbed("No hay nada reproduciéndose ahora.")] });
      return;
    }

    // Loguear estado del player si existe
    if (player) {
      logger.debug(`Player: playing=${player.playing} | paused=${player.paused} | queue=${player.queue.tracks.length} tracks | volume=${player.volume}`);
    }

    const ctx: CommandContext = {
      client,
      message,
      args,
      player: player ?? undefined,
    };

    const startMs = Date.now();
    try {
      await command.execute(ctx);
      logger.info(`Comando "${command.name}" completado en ${Date.now() - startMs}ms`);
    } catch (error) {
      logger.error(`Error en comando "${commandName}" (${Date.now() - startMs}ms):`, error);
      await message
        .reply({ embeds: [errorEmbed(`Error inesperado: \`${(error as Error).message}\``)] })
        .catch(() => null);
    }
  });
}
