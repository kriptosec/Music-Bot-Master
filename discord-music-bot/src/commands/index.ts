import type { Command } from "../types.js";
import { play } from "./play.js";
import { search } from "./search.js";
import { skip, skipto, pause, resume, stop, disconnect, seek } from "./controls.js";
import { queue, nowplaying, remove, move, shuffle, clearQueue, loop } from "./queue.js";
import { volume, filters } from "./audio.js";
import { help, ping, info } from "./info.js";

export const allCommands: Command[] = [
  // Music
  play, search,
  skip, skipto, pause, resume, stop, disconnect, seek,
  // Queue
  queue, nowplaying, remove, move, shuffle, clearQueue, loop,
  // Audio
  volume, filters,
  // Info
  help, ping, info,
];
