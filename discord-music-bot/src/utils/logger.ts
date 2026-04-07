import fs from "fs";
import path from "path";

const logDir = path.resolve(__dirname, "../../logs");
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });

const logStream = fs.createWriteStream(path.join(logDir, "bot.log"), { flags: "a" });

function format(level: string, message: string): string {
  return `${new Date().toISOString()} [${level.padEnd(5)}] ${message}`;
}

function write(level: string, message: string, ...args: unknown[]): void {
  const extra = args.length > 0 ? " " + args.map(a => (a instanceof Error ? a.stack ?? a.message : String(a))).join(" ") : "";
  const line = format(level, message + extra);
  console.log(line);
  logStream.write(line + "\n");
}

export const logger = {
  info: (msg: string, ...args: unknown[]) => write("INFO", msg, ...args),
  warn: (msg: string, ...args: unknown[]) => write("WARN", msg, ...args),
  error: (msg: string, ...args: unknown[]) => write("ERROR", msg, ...args),
  debug: (msg: string, ...args: unknown[]) => {
    if (process.env.DEBUG === "true") write("DEBUG", msg, ...args);
  },
};
