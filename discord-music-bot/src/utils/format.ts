export function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

export function progressBar(position: number, duration: number, length = 20): string {
  if (duration === 0) return "─".repeat(length);
  const filled = Math.round((position / duration) * length);
  return "█".repeat(filled) + "─".repeat(Math.max(0, length - filled));
}

export function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

export function getSourceEmoji(uri: string | null | undefined): string {
  if (!uri) return "🎵";
  if (uri.includes("youtube.com") || uri.includes("youtu.be")) return "🔴";
  if (uri.includes("spotify.com")) return "🟢";
  if (uri.includes("soundcloud.com")) return "🟠";
  if (uri.includes("twitch.tv")) return "🟣";
  return "🎵";
}

export function truncate(str: string, maxLength: number): string {
  if (str.length <= maxLength) return str;
  return str.slice(0, maxLength - 3) + "...";
}

/**
 * Parses a Lavalink/YouTube error and returns a user-friendly Discord message.
 */
export function parseLoadError(rawMessage: string | undefined | null): string {
  const msg = (rawMessage ?? "").toLowerCase();

  if (msg.includes("requires login") || msg.includes("allclientsfailed") || msg.includes("all clients failed")) {
    return "🔒 **Este video requiere inicio de sesión en YouTube.**\nEl bot aún no tiene una cuenta vinculada. Pedile al dueño del servidor que configure el OAuth (ver logs de Lavalink al arrancar). Por ahora probá con otro video o buscá por nombre.";
  }
  if (msg.includes("age restricted") || msg.includes("age-restricted")) {
    return "🔞 **Este video tiene restricción de edad** y no se puede reproducir sin login.";
  }
  if (msg.includes("not available") || msg.includes("video unavailable") || msg.includes("unavailable")) {
    return "❌ **Este video no está disponible** (puede estar eliminado, privado o bloqueado en tu región).";
  }
  if (msg.includes("private video") || msg.includes("private")) {
    return "🔒 **Este video es privado** y no se puede reproducir.";
  }
  if (msg.includes("country") || msg.includes("region") || msg.includes("geo")) {
    return "🌍 **Este video no está disponible en la región del servidor.**";
  }
  if (msg.includes("copyright") || msg.includes("blocked")) {
    return "⛔ **Este video fue bloqueado por derechos de autor.**";
  }
  if (msg.includes("no matches") || msg.includes("no results")) {
    return "🔍 **No se encontraron resultados.** Intentá con otro nombre o URL.";
  }

  if (msg.includes("something went wrong") || msg.includes("loading information")) {
    return "⚠️ **YouTube bloqueó la reproducción.**\nEl plugin de YouTube no pudo cargar el audio. Revisá los logs de Lavalink para el error exacto. Intentá con SoundCloud: `!play scsearch:nombre cancion`";
  }

  // Fallback: show the raw message trimmed
  const display = (rawMessage ?? "Error desconocido").slice(0, 200);
  return `❌ **Error de Lavalink:** \`${display}\``;
}

/**
 * Cleans a YouTube URL by removing Mix/Radio playlist parameters (list=RD...).
 * The old Lavaplayer built-in source can't handle YouTube Radio mixes.
 * Returns { query, stripped } where stripped=true means it was a mix URL.
 */
export function cleanQuery(raw: string): { query: string; stripped: boolean } {
  if (!raw.startsWith("http")) return { query: raw, stripped: false };

  try {
    const url = new URL(raw);
    const list = url.searchParams.get("list") ?? "";
    // YouTube Radio/Mix playlists start with RD — strip them
    if (list.startsWith("RD")) {
      url.searchParams.delete("list");
      url.searchParams.delete("index");
      return { query: url.toString(), stripped: true };
    }
  } catch {
    // Not a valid URL, return as-is
  }

  return { query: raw, stripped: false };
}
