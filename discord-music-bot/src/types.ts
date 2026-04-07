import type {
  ChatInputCommandInteraction,
  Message,
  Client,
  PermissionsString,
} from "discord.js";
import type { LavalinkManager, Player } from "lavalink-client";

declare module "discord.js" {
  interface Client {
    lavalink: LavalinkManager;
    commands: Map<string, Command>;
  }
}

export interface CommandContext {
  client: Client;
  message: Message;
  args: string[];
  player?: Player;
}

export interface Command {
  name: string;
  aliases?: string[];
  description: string;
  usage?: string;
  category: "music" | "queue" | "audio" | "info";
  requiresVoice?: boolean;
  requiresPlayer?: boolean;
  execute(ctx: CommandContext): Promise<void>;
}

export type LoopMode = "off" | "track" | "queue";
