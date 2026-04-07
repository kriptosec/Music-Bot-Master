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
