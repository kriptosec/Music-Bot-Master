import { execFile } from "child_process";
import { existsSync } from "fs";
import { resolve } from "path";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

export const YTDLP_BINARY     = process.env.YTDLP_BINARY     ?? "yt-dlp";
export const YTDLP_PROXY_PORT = process.env.YTDLP_PROXY_PORT ?? "9001";
const PROXY_HOST = "127.0.0.1";

/**
 * Path to a Netscape-format cookies file for YouTube authentication.
 * Set YTDLP_COOKIES env var to override. Default: <project-root>/cookies.txt
 * If the file doesn't exist it is silently ignored.
 */
const COOKIES_FILE =
  process.env.YTDLP_COOKIES ??
  resolve(process.cwd(), "cookies.txt");

// ── Types ─────────────────────────────────────────────────────────────────────

export interface YtDlpInfo {
  title:     string;
  author:    string;
  uri:       string;   // youtube.com watch URL (for display)
  thumbnail: string;
  duration:  number;   // milliseconds
  videoId:   string;
  audioUrl:  string;   // direct CDN URL (expires ~6 h)
  proxyUrl:  string;   // local proxy URL (never expires)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Extracts an 11-char YouTube video ID from any YouTube URL variant. */
export function extractYouTubeVideoId(uri: string | null | undefined): string | null {
  if (!uri) return null;
  try {
    const url = new URL(uri);
    if (url.hostname === "youtu.be") return url.pathname.slice(1).split("?")[0] ?? null;
    if (url.hostname.endsWith("youtube.com"))
      return url.searchParams.get("v");
  } catch { /* not a URL */ }
  const m = uri.match(/[?&]v=([a-zA-Z0-9_-]{11})/);
  return m ? m[1] : null;
}

/** Returns whether a query string targets YouTube (URL or plain-text search). */
export function isYouTubeQuery(query: string): boolean {
  if (query.startsWith("scsearch:")) return false;
  if (query.startsWith("http")) {
    return query.includes("youtube.com") || query.includes("youtu.be");
  }
  return true; // plain-text search defaults to YouTube
}

/** Builds the local proxy URL for a video ID (used in Lavalink HTTP source). */
export function getProxyUrl(videoId: string): string {
  return `http://${PROXY_HOST}:${YTDLP_PROXY_PORT}/track/${videoId}`;
}

/** Returns base yt-dlp args shared across all calls. */
function baseArgs(): string[] {
  const args = [
    "--no-playlist",
    "--no-warnings",
    "--no-config",
    "--js-runtimes", "node",
    // Try multiple clients in order: tv and web_embedded often bypass VPS bot-detection
    "--extractor-args", "youtube:player_client=tv,web_embedded,ios",
    "-f", "bestaudio[ext=webm]/bestaudio[ext=m4a]/bestaudio/best",
  ];

  // Priority 1: extract cookies directly from an installed browser (PC/local use)
  const browser = process.env.COOKIES_FROM_BROWSER;
  if (browser) {
    args.push("--cookies-from-browser", browser);
    return args;
  }

  // Priority 2: use a cookies.txt file (VPS/server use — recommended)
  if (existsSync(COOKIES_FILE)) {
    args.push("--cookies", COOKIES_FILE);
    console.log(`[ytdlp] Using cookies file: ${COOKIES_FILE}`);
  }

  return args;
}

// ── Core: single yt-dlp call for metadata + audio URL ────────────────────────

/**
 * Searches YouTube (or loads a direct URL) using yt-dlp.
 * Returns metadata AND a direct CDN audio URL in ONE process call.
 *
 * Uses `-j` (JSON dump) with `-f bestaudio` to get the selected format URL.
 */
export async function ytdlpSearch(query: string): Promise<YtDlpInfo | null> {
  const searchArg = query.startsWith("http") ? query : `ytsearch:${query}`;
  const args = [...baseArgs(), "-j", searchArg];

  try {
    const { stdout, stderr } = await execFileAsync(YTDLP_BINARY, args, { timeout: 90_000 });

    if (!stdout.trim()) {
      console.error("[ytdlp] empty stdout. stderr:", stderr?.slice(0, 500));
      return null;
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const j: any = JSON.parse(stdout.trim());

    const videoId: string = j.id ?? "";
    if (!videoId) return null;

    // Prefer the url of the requested_downloads if present, else the top-level url
    const audioUrl: string =
      j.requested_downloads?.[0]?.url ??
      j.url ??
      "";

    return {
      title:     String(j.title    ?? "Unknown"),
      author:    String(j.channel ?? j.uploader ?? "Unknown"),
      uri:       String(j.webpage_url ?? `https://www.youtube.com/watch?v=${videoId}`),
      thumbnail: String(j.thumbnail ?? ""),
      duration:  Math.round((Number(j.duration) || 0) * 1000),
      videoId,
      audioUrl,
      proxyUrl:  getProxyUrl(videoId),
    };
  } catch (e: unknown) {
    const err = e as { killed?: boolean; signal?: string; stderr?: string; code?: number | null };
    if (err.killed && err.signal === "SIGTERM") {
      console.error("[ytdlp] process timed out (90s). Is yt-dlp installed and working?");
    } else {
      const msg = err.stderr?.trim() || String(e);
      console.error("[ytdlp] search error:", msg.slice(0, 600));
      if (msg.includes("Sign in to confirm")) {
        console.error(
          "[ytdlp] YouTube bot-detection activo en este IP.\n" +
          "[ytdlp] Solución: exporta cookies de YouTube y colócalas en:\n" +
          `[ytdlp]   ${COOKIES_FILE}\n` +
          "[ytdlp] Guía: https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp"
        );
      }
    }
    return null;
  }
}
