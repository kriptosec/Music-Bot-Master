import os
from dotenv import load_dotenv

load_dotenv()

DISCORD_TOKEN = os.getenv("DISCORD_TOKEN", "")
LAVALINK_HOST = os.getenv("LAVALINK_HOST", "127.0.0.1")
LAVALINK_PORT = int(os.getenv("LAVALINK_PORT", "2333"))
LAVALINK_PASSWORD = os.getenv("LAVALINK_PASSWORD", "r2dd2pass")
BOT_PREFIX = os.getenv("BOT_PREFIX", "!")
INACTIVE_TIMEOUT = int(os.getenv("INACTIVE_TIMEOUT", "300"))
