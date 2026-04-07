import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

export const YTDLP_BINARY   = process.env.YTDLP_BINARY   ?? "yt-dlp";
export const YTDLP_PROXY_PORT = process.env.YTDLP_PROXY_PORT ?? "9001";
const PROXY_HOST = "127.0.0.1";

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

// ── Core: single yt-dlp call for metadata + audio URL ────────────────────────

/**
 * Searches YouTube (or loads a direct URL) using yt-dlp.
 * Returns metadata AND a direct CDN audio URL in ONE process call.
 *
 * Uses `-j` (JSON dump) with `-f bestaudio` to get the selected format URL.
 */
export async function ytdlpSearch(query: string): Promise<YtDlpInfo | null> {
  const searchArg = query.startsWith("http") ? query : `ytsearch:${query}`;
  const args = [
    "--no-playlist",
    "--no-warnings",
    "-f", "bestaudio[ext=webm]/bestaudio[ext=m4a]/bestaudio/best",
    "-j",
    searchArg,
  ];

  try {
    const { stdout } = await execFileAsync(YTDLP_BINARY, args, { timeout: 30_000 });
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
  } catch (e) {
    console.error("[ytdlp] search error:", e);
    return null;
  }
}
