import asyncio
import logging
import os
import sys

import discord
import wavelink
from discord.ext import commands

import config

log_dir = os.path.join(os.path.dirname(__file__), "logs")
os.makedirs(log_dir, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(os.path.join(log_dir, "bot.log"), encoding="utf-8"),
    ],
)
logger = logging.getLogger("music-bot")


class MusicBot(commands.Bot):
    def __init__(self) -> None:
        intents = discord.Intents.default()
        intents.message_content = True
        intents.voice_states = True
        intents.guilds = True
        super().__init__(
            command_prefix=config.BOT_PREFIX,
            intents=intents,
            help_command=None,
        )

    async def setup_hook(self) -> None:
        await self.load_extension("cogs.music")
        await self.load_extension("cogs.help")

        uri = f"http://{config.LAVALINK_HOST}:{config.LAVALINK_PORT}"
        node = wavelink.Node(
            uri=uri,
            password=config.LAVALINK_PASSWORD,
            inactive_player_timeout=config.INACTIVE_TIMEOUT,
        )
        await wavelink.Pool.connect(nodes=[node], client=self, cache_capacity=100)
        logger.info(f"Lavalink node connecting to {uri}")

    async def on_ready(self) -> None:
        logger.info(f"Logged in as {self.user} | ID: {self.user.id}")
        await self.change_presence(
            activity=discord.Activity(
                type=discord.ActivityType.listening,
                name=f"{config.BOT_PREFIX}help | Music Bot",
            )
        )

    async def on_wavelink_node_ready(
        self, payload: wavelink.NodeReadyEventPayload
    ) -> None:
        logger.info(f"Lavalink node {payload.node!r} is ready! Session: {payload.session_id}")

    async def on_command_error(
        self, ctx: commands.Context, error: commands.CommandError
    ) -> None:
        if isinstance(error, commands.CommandNotFound):
            return
        if isinstance(error, commands.MissingRequiredArgument):
            await ctx.send(f"❌ Falta un argumento: `{error.param.name}`. Usa `{config.BOT_PREFIX}help` para más información.")
            return
        if isinstance(error, commands.BadArgument):
            await ctx.send(f"❌ Argumento inválido. Usa `{config.BOT_PREFIX}help` para más información.")
            return
        logger.error(f"Error en comando '{ctx.command}': {error}", exc_info=error)
        await ctx.send(f"❌ Error inesperado: `{error}`")


async def main() -> None:
    bot = MusicBot()
    if not config.DISCORD_TOKEN:
        logger.error("DISCORD_TOKEN no configurado en .env")
        sys.exit(1)
    async with bot:
        await bot.start(config.DISCORD_TOKEN)


if __name__ == "__main__":
    asyncio.run(main())
