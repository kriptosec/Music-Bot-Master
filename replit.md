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

Located in `discord-music-bot/` — a standalone, portable Python Discord music bot.

### Stack
- **Language**: Python 3.10+
- **Discord library**: discord.py 2.3+
- **Audio**: Lavalink v4 + wavelink 3.4+
- **Sources**: YouTube (OAuth), Spotify, SoundCloud
- **Plugin**: youtube-plugin (snapshot) via maven.lavalink.dev/snapshots

### Key files
- `discord-music-bot/main.py` — Bot entry point
- `discord-music-bot/cogs/music.py` — All music commands
- `discord-music-bot/cogs/help.py` — Help and info commands
- `discord-music-bot/lavalink/application.yml` — Lavalink config (OAuth, plugins)
- `discord-music-bot/.env` — Bot token and settings

### Scripts
- `bash scripts/install.sh` — Install everything (venv, deps, Lavalink.jar)
- `bash scripts/start.sh` — Start Lavalink + bot
- `bash scripts/stop.sh` — Stop everything
- `bash scripts/status.sh` — Check status + last logs
- `bash scripts/update.sh` — Update deps + Lavalink (--force to reinstall all)
