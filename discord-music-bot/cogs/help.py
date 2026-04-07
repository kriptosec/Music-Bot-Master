import discord
from discord.ext import commands

import config


class Help(commands.Cog):
    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot

    @commands.command(name="help", aliases=["h", "ayuda", "commands", "comandos"])
    async def help_cmd(self, ctx: commands.Context, *, command_name: str = None) -> None:
        """Muestra la lista de comandos disponibles."""
        prefix = config.BOT_PREFIX

        if command_name:
            cmd = self.bot.get_command(command_name)
            if not cmd:
                await ctx.send(f"❌ Comando `{command_name}` no encontrado.")
                return
            embed = discord.Embed(
                title=f"📖 Ayuda: `{prefix}{cmd.name}`",
                description=cmd.help or "Sin descripción.",
                color=discord.Color.blurple(),
            )
            if cmd.aliases:
                embed.add_field(name="Aliases", value=", ".join(f"`{a}`" for a in cmd.aliases))
            await ctx.send(embed=embed)
            return

        embed = discord.Embed(
            title="🎵 Music Bot — Comandos",
            description=f"Prefijo: `{prefix}` | Para ayuda de un comando: `{prefix}help <comando>`",
            color=discord.Color.from_rgb(114, 137, 218),
        )

        embed.add_field(
            name="▶️ Reproducción",
            value=f"`{prefix}play <canción>` — Reproduce o agrega a la cola\n"
                  f"`{prefix}search <canción>` — Busca y elige una canción\n"
                  f"`{prefix}pause` — Pausa/reanuda\n"
                  f"`{prefix}resume` — Reanuda la reproducción\n"
                  f"`{prefix}stop` — Detiene y limpia la cola\n"
                  f"`{prefix}skip` — Salta la canción actual\n"
                  f"`{prefix}skipto <número>` — Salta a una posición\n"
                  f"`{prefix}seek <tiempo>` — Salta a un tiempo (ej: `1:30`)\n"
                  f"`{prefix}nowplaying` — Canción actual",
            inline=False,
        )

        embed.add_field(
            name="📋 Cola",
            value=f"`{prefix}queue [página]` — Ver la cola\n"
                  f"`{prefix}remove <número>` — Eliminar una canción\n"
                  f"`{prefix}move <de> <a>` — Mover una canción\n"
                  f"`{prefix}shuffle` — Mezclar aleatoriamente\n"
                  f"`{prefix}clear` — Limpiar toda la cola\n"
                  f"`{prefix}loop <track|queue|off>` — Modo repetición",
            inline=False,
        )

        embed.add_field(
            name="🎚️ Audio",
            value=f"`{prefix}volume <0-200>` — Ajustar volumen\n"
                  f"`{prefix}filters [preset]` — Filtros de audio",
            inline=False,
        )

        embed.add_field(
            name="🔌 Conexión",
            value=f"`{prefix}disconnect` — Desconectar el bot",
            inline=False,
        )

        embed.add_field(
            name="🎯 Fuentes soportadas",
            value="YouTube • Spotify • SoundCloud • URLs directas",
            inline=False,
        )

        embed.set_footer(text="Music Bot v2.0 | Lavalink + Wavelink")
        await ctx.send(embed=embed)

    @commands.command(name="ping")
    async def ping(self, ctx: commands.Context) -> None:
        """Muestra la latencia del bot."""
        latency = round(self.bot.latency * 1000)
        node = None
        try:
            node = list(self.bot.wavelink_pool.nodes.values())[0] if hasattr(self.bot, 'wavelink_pool') else None
        except Exception:
            pass

        embed = discord.Embed(title="🏓 Pong!", color=discord.Color.green())
        embed.add_field(name="Bot", value=f"`{latency}ms`", inline=True)
        await ctx.send(embed=embed)

    @commands.command(name="info")
    async def info(self, ctx: commands.Context) -> None:
        """Muestra información del bot."""
        embed = discord.Embed(
            title="ℹ️ Información del Bot",
            color=discord.Color.blurple(),
        )
        embed.add_field(name="Versión", value="`2.0.0`", inline=True)
        embed.add_field(name="Librería", value="`discord.py + wavelink`", inline=True)
        embed.add_field(name="Audio", value="`Lavalink v4`", inline=True)
        embed.add_field(name="Servidores", value=f"`{len(self.bot.guilds)}`", inline=True)
        embed.add_field(name="Prefijo", value=f"`{config.BOT_PREFIX}`", inline=True)
        if self.bot.user and self.bot.user.avatar:
            embed.set_thumbnail(url=self.bot.user.avatar.url)
        await ctx.send(embed=embed)


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Help(bot))
