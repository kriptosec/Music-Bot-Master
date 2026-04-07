import fs from "fs";
import path from "path";

const logDir = path.resolve(__dirname, "../../logs");
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });

const logStream = fs.createWriteStream(path.join(logDir, "bot.log"), { flags: "a" });

const LEVELS: Record<string, number> = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 };
const DEBUG_MODE = process.env.DEBUG === "true";

const COLORS: Record<string, string> = {
  DEBUG: "\x1b[36m", // cyan
  INFO:  "\x1b[32m", // green
  WARN:  "\x1b[33m", // yellow
  ERROR: "\x1b[31m", // red
  RESET: "\x1b[0m",
  DIM:   "\x1b[2m",
  BOLD:  "\x1b[1m",
};

function serializeArg(a: unknown): string {
  if (a instanceof Error) return `\n  ${a.stack ?? a.message}`;
  if (typeof a === "object" && a !== null) {
    try { return JSON.stringify(a, null, 2); } catch { return String(a); }
  }
  return String(a);
}

function write(level: string, message: string, ...args: unknown[]): void {
  if (!DEBUG_MODE && level === "DEBUG") return;

  const ts = new Date().toISOString();
  const extra = args.length > 0 ? " " + args.map(serializeArg).join(" ") : "";
  const plain = `${ts} [${level.padEnd(5)}] ${message}${extra}`;

  // Colored output for the console
  const color = COLORS[level] ?? "";
  const colored = `${COLORS.DIM}${ts}${COLORS.RESET} ${color}${COLORS.BOLD}[${level.padEnd(5)}]${COLORS.RESET} ${message}${extra}`;

  process.stdout.write(colored + "\n");
  logStream.write(plain + "\n");
}

export const logger = {
  debug: (msg: string, ...args: unknown[]) => write("DEBUG", msg, ...args),
  info:  (msg: string, ...args: unknown[]) => write("INFO",  msg, ...args),
  warn:  (msg: string, ...args: unknown[]) => write("WARN",  msg, ...args),
  error: (msg: string, ...args: unknown[]) => write("ERROR", msg, ...args),

  // Separador visual para momentos importantes
  separator: (label: string) => {
    const line = `${"─".repeat(50)}`;
    const msg = `${line}\n  ${label}\n${line}`;
    write("INFO", msg);
  },
};
