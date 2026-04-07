# Workspace

## Overview

pnpm workspace monorepo using TypeScript. Each package manages its own dependencies.

## Stack

- **Monorepo tool**: pnpm workspaces
- **Node.js version**: 24
- **Package manager**: pnpm
- **TypeScript version**: 5.9
- **API framework**: Express 5
- **Database**: PostgreSQL + Drizzle ORM
- **Validation**: Zod (`zod/v4`), `drizzle-zod`
- **API codegen**: Orval (from OpenAPI spec)
- **Build**: esbuild (CJS bundle)

## Key Commands

- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- `pnpm --filter @workspace/api-server run dev` — run API server locally

See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details.

## Discord Music Bot

Located in `discord-music-bot/` — a standalone, portable TypeScript Discord music bot.

### Stack
- **Language**: TypeScript (compiled to Node.js)
- **Discord library**: discord.js v14
- **Audio client**: lavalink-client v2 (actively maintained, updated weekly)
- **Audio server**: Lavalink v4
- **Sources**: YouTube (OAuth plugin), Spotify, SoundCloud, URLs
- **Plugin**: youtube-plugin (snapshot) via maven.lavalink.dev/snapshots

### Why TypeScript over Python
wavelink (Python) was archived in July 2024 — no more updates or security patches.
lavalink-client (TypeScript) is updated actively in 2025/2026 with full Lavalink v4 support.

### Key files
- `discord-music-bot/src/index.ts` — Bot entry point
- `discord-music-bot/src/config.ts` — Config from .env
- `discord-music-bot/src/commands/` — All music/queue/audio/info commands
- `discord-music-bot/src/events/` — Discord + Lavalink event handlers
- `discord-music-bot/src/utils/` — Formatters, embeds, logger
- `discord-music-bot/lavalink/application.yml` — Lavalink config (OAuth, plugins)
- `discord-music-bot/.env` — Bot token and settings

### Scripts
- `bash scripts/install.sh` — Install Node.js deps, compile TS, download Lavalink.jar
- `bash scripts/start.sh` — Start Lavalink + bot
- `bash scripts/stop.sh` — Stop everything
- `bash scripts/status.sh` — Check status + last logs
- `bash scripts/update.sh` — Update deps + recompile + restart (--force to reinstall all)
