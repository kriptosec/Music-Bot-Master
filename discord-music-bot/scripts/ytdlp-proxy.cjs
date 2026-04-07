'use strict';

const http     = require('http');
const { execFile } = require('child_process');
const { existsSync } = require('fs');
const { resolve }   = require('path');
const { URL }  = require('url');

const PORT       = parseInt(process.env.YTDLP_PROXY_PORT ?? '9001', 10);
const HOST       = '127.0.0.1';
const YTDLP_BIN  = process.env.YTDLP_BINARY ?? 'yt-dlp';
const CACHE_TTL  = 60 * 60 * 1000; // 1 hour — yt-dlp CDN URLs last ~6 h

const COOKIES_FILE =
  process.env.YTDLP_COOKIES ??
  resolve(process.cwd(), 'cookies.txt');

// Simple in-memory cache: videoId -> { url, ts }
const cache = new Map();

function getCached(videoId) {
  const entry = cache.get(videoId);
  if (entry && Date.now() - entry.ts < CACHE_TTL) return entry.url;
  return null;
}

function setCached(videoId, url) {
  cache.set(videoId, { url, ts: Date.now() });
}

function fetchAudioUrl(videoId, cb) {
  const cached = getCached(videoId);
  if (cached) return cb(null, cached);

  const args = [
    '--no-playlist',
    '--no-warnings',
    '--no-config',
    '--js-runtimes', 'node',
    '--remote-components', 'ejs:github',
    '--extractor-args', 'youtube:player_client=tv,web_embedded',
    '-f', 'bestaudio[ext=webm]/bestaudio[ext=m4a]/bestaudio/best',
    '-j',
    `https://www.youtube.com/watch?v=${videoId}`,
  ];

  // Priority 1: extract cookies from an installed browser (PC/local)
  const browser = process.env.COOKIES_FROM_BROWSER;
  if (browser) {
    args.push('--cookies-from-browser', browser);
  } else if (existsSync(COOKIES_FILE)) {
    // Priority 2: cookies.txt file (VPS/server — recommended)
    args.push('--cookies', COOKIES_FILE);
  }

  execFile(YTDLP_BIN, args, { timeout: 60_000 }, (err, stdout, stderr) => {
    if (err) {
      const msg = stderr?.trim() || err.message;
      return cb(new Error(msg.slice(0, 300)), null);
    }
    try {
      const j = JSON.parse(stdout.trim());
      const url = j.requested_downloads?.[0]?.url ?? j.url ?? '';
      if (!url.startsWith('http')) return cb(new Error('yt-dlp: no audio URL in JSON'), null);
      setCached(videoId, url);
      cb(null, url);
    } catch (e) {
      cb(new Error('yt-dlp: JSON parse error'), null);
    }
  });
}

const server = http.createServer((req, res) => {
  const path = new URL(req.url, `http://${HOST}:${PORT}`).pathname;

  if (path === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ ok: true, cacheSize: cache.size }));
  }

  const m = path.match(/^\/track\/([a-zA-Z0-9_-]{11})$/);
  if (!m) {
    res.writeHead(400);
    return res.end('Expected /track/:videoId (11 chars)');
  }

  const videoId = m[1];
  console.log(`[proxy] ${videoId} — ${getCached(videoId) ? 'cache HIT' : 'calling yt-dlp...'}`);

  fetchAudioUrl(videoId, (err, url) => {
    if (err) {
      console.error(`[proxy] ${videoId} ERROR:`, err.message);
      res.writeHead(502);
      return res.end(err.message);
    }
    console.log(`[proxy] ${videoId} → redirect`);
    res.writeHead(302, { Location: url });
    res.end();
  });
});

server.listen(PORT, HOST, () =>
  console.log(`[ytdlp-proxy] Listening on http://${HOST}:${PORT}`)
);

server.on('error', (err) => { console.error('[proxy] fatal:', err); process.exit(1); });

process.on('SIGTERM', () => server.close(() => { console.log('[proxy] stopped'); process.exit(0); }));
