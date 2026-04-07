import asyncio
import logging
import math
import random
from typing import Optional, cast

import discord
import wavelink
from discord.ext import commands

import config

logger = logging.getLogger("music-bot.music")


def format_duration(ms: int) -> str:
    seconds = ms // 1000
    minutes = seconds // 60
    hours = minutes // 60
    seconds %= 60
    minutes %= 60
    if hours > 0:
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    return f"{minutes}:{seconds:02d}"


def progress_bar(position: int, duration: int, length: int = 20) -> str:
    if duration == 0:
        return "─" * length
    filled = int((position / duration) * length)
    bar = "█" * filled + "─" * (length - filled)
    return bar


class Music(commands.Cog):
    def __init__(self, bot: commands.Bot) -> None:
        self.bot = bot

    async def cog_before_invoke(self, ctx: commands.Context) -> None:
        pass

    def _get_player(self, ctx: commands.Context) -> Optional[wavelink.Player]:
        return cast(Optional[wavelink.Player], ctx.voice_client)

    async def _ensure_player(self, ctx: commands.Context) -> Optional[wavelink.Player]:
        player = self._get_player(ctx)
        if player:
            return player
        if not ctx.author.voice:
            await ctx.send("❌ Debes estar en un canal de voz primero.")
            return None
        try:
            player = await ctx.author.voice.channel.connect(cls=wavelink.Player)
            player.home = ctx.channel
            player.autoplay = wavelink.AutoPlayMode.partial
            return player
        except Exception as e:
            logger.error(f"Error al conectar al canal de voz: {e}")
            await ctx.send(f"❌ No pude conectarme al canal de voz: `{e}`")
            return None

    @commands.Cog.listener()
    async def on_wavelink_track_start(
        self, payload: wavelink.TrackStartEventPayload
    ) -> None:
        player: wavelink.Player = payload.player
        track: wavelink.Playable = payload.track
        channel = getattr(player, "home", None)
        if not channel:
            return

        embed = discord.Embed(
            title="🎵 Reproduciendo ahora",
            color=discord.Color.from_rgb(114, 137, 218),
        )
        embed.description = f"**[{track.title}]({track.uri})**\n👤 {track.author}"

        if track.artwork:
            embed.set_thumbnail(url=track.artwork)

        embed.add_field(
            name="Duración",
            value=f"`{format_duration(track.length)}`" if not track.is_stream else "`🔴 En vivo`",
            inline=True,
        )

        source = "🎵 Desconocido"
        if track.uri:
            if "youtube.com" in track.uri or "youtu.be" in track.uri:
                source = "<:youtube:1234> YouTube"
            elif "spotify.com" in track.uri:
                source = "🟢 Spotify"
            elif "soundcloud.com" in track.uri:
                source = "🟠 SoundCloud"
        embed.add_field(name="Fuente", value=source, inline=True)

        queue_size = len(player.queue)
        if queue_size > 0:
            embed.add_field(name="En cola", value=f"`{queue_size}` canciones", inline=True)

        embed.set_footer(text=f"Pedida por {track.extras.requester if hasattr(track, 'extras') and track.extras else 'Alguien'}")
        await channel.send(embed=embed)

    @commands.Cog.listener()
    async def on_wavelink_track_end(
        self, payload: wavelink.TrackEndEventPayload
    ) -> None:
        player: wavelink.Player = payload.player
        if player.queue.is_empty and not player.auto_queue.is_empty:
            return
        if player.queue.is_empty:
            channel = getattr(player, "home", None)
            if channel:
                await channel.send("✅ Cola terminada. Usa `!play` para agregar más canciones.")

    @commands.Cog.listener()
    async def on_wavelink_inactive_player(self, player: wavelink.Player) -> None:
        channel = getattr(player, "home", None)
        if channel:
            await channel.send("⏹️ Bot inactivo por inactividad. Desconectando...")
        await player.disconnect()

    @commands.Cog.listener()
    async def on_wavelink_node_ready(
        self, payload: wavelink.NodeReadyEventPayload
    ) -> None:
        logger.info(f"Nodo Lavalink listo: {payload.node!r}")

    @commands.command(name="play", aliases=["p", "tocar", "reproducir"])
    async def play(self, ctx: commands.Context, *, query: str) -> None:
        """Reproduce una canción o la agrega a la cola. Soporta YouTube, Spotify y URLs."""
        player = await self._ensure_player(ctx)
        if not player:
            return

        if not hasattr(player, "home"):
            player.home = ctx.channel

        async with ctx.typing():
            try:
                tracks: wavelink.Search = await wavelink.Playable.search(query)
            except Exception as e:
                logger.error(f"Error buscando '{query}': {e}")
                await ctx.send(f"❌ Error al buscar: `{e}`")
                return

        if not tracks:
            await ctx.send(f"❌ No encontré resultados para: `{query}`")
            return

        if isinstance(tracks, wavelink.Playlist):
            added = await player.queue.put_wait(tracks)
            embed = discord.Embed(
                title="📃 Lista agregada",
                description=f"**{tracks.name}**\n`{added}` canciones agregadas a la cola.",
                color=discord.Color.green(),
            )
            await ctx.send(embed=embed)
        else:
            track: wavelink.Playable = tracks[0]
            await player.queue.put_wait(track)
            if player.playing:
                embed = discord.Embed(
                    title="✅ Agregado a la cola",
                    description=f"**[{track.title}]({track.uri})**",
                    color=discord.Color.blue(),
                )
                embed.add_field(name="Duración", value=f"`{format_duration(track.length)}`", inline=True)
                embed.add_field(name="Posición en cola", value=f"`#{len(player.queue)}`", inline=True)
                if track.artwork:
                    embed.set_thumbnail(url=track.artwork)
                await ctx.send(embed=embed)

        if not player.playing:
            track = player.queue.get()
            await player.play(track, populate=False)

    @commands.command(name="search", aliases=["buscar"])
    async def search(self, ctx: commands.Context, *, query: str) -> None:
        """Busca canciones en YouTube y permite elegir cuál reproducir."""
        async with ctx.typing():
            try:
                tracks = await wavelink.Playable.search(query)
            except Exception as e:
                await ctx.send(f"❌ Error al buscar: `{e}`")
                return

        if not tracks:
            await ctx.send(f"❌ No encontré resultados para: `{query}`")
            return

        results = tracks[:5] if not isinstance(tracks, wavelink.Playlist) else []
        if not results:
            await ctx.send("❌ No se encontraron resultados individuales. Intenta con `!play` directamente.")
            return

        embed = discord.Embed(
            title=f"🔍 Resultados para: {query[:50]}",
            color=discord.Color.blurple(),
        )
        desc = []
        for i, t in enumerate(results, 1):
            desc.append(f"`{i}.` **{t.title}** — `{t.author}` — `{format_duration(t.length)}`")
        embed.description = "\n".join(desc)
        embed.set_footer(text="Responde con el número (1-5) o 'cancelar'")
        msg = await ctx.send(embed=embed)

        def check(m: discord.Message) -> bool:
            return (
                m.author == ctx.author
                and m.channel == ctx.channel
                and (m.content.isdigit() and 1 <= int(m.content) <= len(results) or m.content.lower() in ("cancelar", "cancel"))
            )

        try:
            reply = await self.bot.wait_for("message", check=check, timeout=30)
        except asyncio.TimeoutError:
            await msg.edit(content="⏰ Tiempo agotado.", embed=None)
            return

        if reply.content.lower() in ("cancelar", "cancel"):
            await msg.edit(content="❌ Búsqueda cancelada.", embed=None)
            return

        selected = results[int(reply.content) - 1]
        player = await self._ensure_player(ctx)
        if not player:
            return

        if not hasattr(player, "home"):
            player.home = ctx.channel

        await player.queue.put_wait(selected)
        if not player.playing:
            await player.play(player.queue.get(), populate=False)
        else:
            await ctx.send(f"✅ **{selected.title}** agregado a la cola en posición `#{len(player.queue)}`")

    @commands.command(name="skip", aliases=["s", "saltar", "siguiente"])
    async def skip(self, ctx: commands.Context) -> None:
        """Salta la canción actual."""
        player = self._get_player(ctx)
        if not player or not player.playing:
            await ctx.send("❌ No hay nada reproduciéndose.")
            return
        current = player.current
        await player.skip(force=True)
        await ctx.send(f"⏭️ Saltado: **{current.title}**")

    @commands.command(name="skipto", aliases=["st"])
    async def skipto(self, ctx: commands.Context, position: int) -> None:
        """Salta a una posición específica en la cola."""
        player = self._get_player(ctx)
        if not player:
            await ctx.send("❌ No estoy en un canal de voz.")
            return
        if player.queue.is_empty:
            await ctx.send("❌ La cola está vacía.")
            return
        if position < 1 or position > len(player.queue):
            await ctx.send(f"❌ Posición inválida. La cola tiene `{len(player.queue)}` canciones.")
            return

        for _ in range(position - 1):
            player.queue.get()

        await player.skip(force=True)
        await ctx.send(f"⏭️ Saltando a la posición `{position}` en la cola.")

    @commands.command(name="pause", aliases=["pausar"])
    async def pause(self, ctx: commands.Context) -> None:
        """Pausa o reanuda la reproducción."""
        player = self._get_player(ctx)
        if not player:
            await ctx.send("❌ No estoy en un canal de voz.")
            return
        if not player.playing and not player.paused:
            await ctx.send("❌ No hay nada reproduciéndose.")
            return
        await player.pause(not player.paused)
        if player.paused:
            await ctx.send("⏸️ Pausado.")
        else:
            await ctx.send("▶️ Reanudado.")

    @commands.command(name="resume", aliases=["reanudar"])
    async def resume(self, ctx: commands.Context) -> None:
        """Reanuda la reproducción si está pausada."""
        player = self._get_player(ctx)
        if not player or not player.paused:
            await ctx.send("❌ No hay nada pausado.")
            return
        await player.pause(False)
        await ctx.send("▶️ Reanudado.")

    @commands.command(name="stop", aliases=["detener", "parar"])
    async def stop(self, ctx: commands.Context) -> None:
        """Detiene la reproducción y limpia la cola."""
        player = self._get_player(ctx)
        if not player:
            await ctx.send("❌ No estoy en un canal de voz.")
            return
        player.queue.clear()
        await player.stop()
        await ctx.send("⏹️ Reproducción detenida y cola limpiada.")

    @commands.command(name="disconnect", aliases=["dc", "salir", "leave", "desconectar"])
    async def disconnect(self, ctx: commands.Context) -> None:
        """Desconecta el bot del canal de voz."""
        player = self._get_player(ctx)
        if not player:
            await ctx.send("❌ No estoy en un canal de voz.")
            return
        player.queue.clear()
        await player.disconnect()
        await ctx.send("👋 Desconectado.")

    @commands.command(name="queue", aliases=["q", "cola", "lista"])
    async def queue(self, ctx: commands.Context, page: int = 1) -> None:
        """Muestra la cola de reproducción."""
        player = self._get_player(ctx)
        if not player or (player.queue.is_empty and not player.playing):
            await ctx.send("📭 La cola está vacía.")
            return

        items_per_page = 10
        queue_list = list(player.queue)
        total_pages = max(1, math.ceil(len(queue_list) / items_per_page))
        page = max(1, min(page, total_pages))

        embed = discord.Embed(
            title="📋 Cola de Reproducción",
            color=discord.Color.from_rgb(114, 137, 218),
        )

        if player.current:
            embed.add_field(
                name="▶️ Reproduciendo ahora",
                value=f"**[{player.current.title}]({player.current.uri})**\n"
                      f"⏱️ `{format_duration(player.position)} / {format_duration(player.current.length)}`",
                inline=False,
            )

        if queue_list:
            start = (page - 1) * items_per_page
            end = start + items_per_page
            entries = []
            for i, track in enumerate(queue_list[start:end], start=start + 1):
                entries.append(
                    f"`{i}.` **{track.title[:50]}**\n"
                    f"     👤 {track.author} • ⏱️ `{format_duration(track.length)}`"
                )
            embed.add_field(
                name=f"📝 Cola ({len(queue_list)} canciones)",
                value="\n".join(entries),
                inline=False,
            )
            total_duration = sum(t.length for t in queue_list)
            embed.set_footer(
                text=f"Página {page}/{total_pages} • Duración total: {format_duration(total_duration)}"
            )
        else:
            embed.add_field(name="📝 Cola", value="La cola está vacía.", inline=False)

        await ctx.send(embed=embed)

    @commands.command(name="nowplaying", aliases=["np", "ahora", "current"])
    async def nowplaying(self, ctx: commands.Context) -> None:
        """Muestra información de la canción actual."""
        player = self._get_player(ctx)
        if not player or not player.current:
            await ctx.send("❌ No hay nada reproduciéndose.")
            return

        track = player.current
        embed = discord.Embed(
            title="🎵 Reproduciendo ahora",
            description=f"**[{track.title}]({track.uri})**\n👤 {track.author}",
            color=discord.Color.from_rgb(114, 137, 218),
        )

        if not track.is_stream:
            pos = player.position
            bar = progress_bar(pos, track.length)
            embed.add_field(
                name="Progreso",
                value=f"`{format_duration(pos)}` {bar} `{format_duration(track.length)}`",
                inline=False,
            )
        else:
            embed.add_field(name="Estado", value="`🔴 En vivo`", inline=True)

        if track.artwork:
            embed.set_thumbnail(url=track.artwork)

        loop_status = "🔁 Sí" if player.queue.mode == wavelink.QueueMode.loop else (
            "🔁 Cola" if player.queue.mode == wavelink.QueueMode.loop_all else "❌ No"
        )
        embed.add_field(name="Repetir", value=loop_status, inline=True)
        embed.add_field(name="Volumen", value=f"`{player.volume}%`", inline=True)
        embed.add_field(name="En cola", value=f"`{len(player.queue)}`", inline=True)
        await ctx.send(embed=embed)

    @commands.command(name="volume", aliases=["vol", "volumen"])
    async def volume(self, ctx: commands.Context, vol: int) -> None:
        """Ajusta el volumen del bot (0-200)."""
        player = self._get_player(ctx)
        if not player:
            await ctx.send("❌ No estoy en un canal de voz.")
            return
        if not 0 <= vol <= 200:
            await ctx.send("❌ El volumen debe estar entre `0` y `200`.")
            return
        await player.set_volume(vol)
        emoji = "🔇" if vol == 0 else "🔉" if vol < 50 else "🔊"
        await ctx.send(f"{emoji} Volumen ajustado a `{vol}%`")

    @commands.command(name="loop", aliases=["repetir", "repeat"])
    async def loop(self, ctx: commands.Context, mode: str = "track") -> None:
        """Cambia el modo de repetición. Opciones: track, queue, off."""
        player = self._get_player(ctx)
        if not player:
            await ctx.send("❌ No estoy en un canal de voz.")
            return

        mode_lower = mode.lower()
        if mode_lower in ("track", "cancion", "song", "1"):
            player.queue.mode = wavelink.QueueMode.loop
            await ctx.send("🔁 Repitiendo la canción actual.")
        elif mode_lower in ("queue", "cola", "all", "todo", "2"):
            player.queue.mode = wavelink.QueueMode.loop_all
            await ctx.send("🔁 Repitiendo toda la cola.")
        elif mode_lower in ("off", "no", "apagar", "desactivar", "0"):
            player.queue.mode = wavelink.QueueMode.normal
            await ctx.send("❌ Repetición desactivada.")
        else:
            await ctx.send("❌ Modo inválido. Usa: `track`, `queue`, u `off`.")

    @commands.command(name="shuffle", aliases=["mezclar", "aleatorio"])
    async def shuffle(self, ctx: commands.Context) -> None:
        """Mezcla la cola de reproducción aleatoriamente."""
        player = self._get_player(ctx)
        if not player or player.queue.is_empty:
            await ctx.send("❌ La cola está vacía.")
            return
        player.queue.shuffle()
        await ctx.send(f"🔀 Cola mezclada. `{len(player.queue)}` canciones en la cola.")

    @commands.command(name="remove", aliases=["eliminar", "quitar"])
    async def remove(self, ctx: commands.Context, position: int) -> None:
        """Elimina una canción de la cola por su posición."""
        player = self._get_player(ctx)
        if not player or player.queue.is_empty:
            await ctx.send("❌ La cola está vacía.")
            return
        if position < 1 or position > len(player.queue):
            await ctx.send(f"❌ Posición inválida. La cola tiene `{len(player.queue)}` canciones.")
            return

        queue_list = list(player.queue)
        removed = queue_list.pop(position - 1)
        player.queue.clear()
        for t in queue_list:
            await player.queue.put_wait(t)

        await ctx.send(f"🗑️ Eliminado de la cola: **{removed.title}**")

    @commands.command(name="clear", aliases=["limpiar", "vaciar"])
    async def clear(self, ctx: commands.Context) -> None:
        """Limpia toda la cola de reproducción."""
        player = self._get_player(ctx)
        if not player or player.queue.is_empty:
            await ctx.send("❌ La cola ya está vacía.")
            return
        count = len(player.queue)
        player.queue.clear()
        await ctx.send(f"🗑️ Cola limpiada. `{count}` canciones eliminadas.")

    @commands.command(name="seek", aliases=["ir"])
    async def seek(self, ctx: commands.Context, position: str) -> None:
        """Salta a una posición específica. Formato: segundos o MM:SS."""
        player = self._get_player(ctx)
        if not player or not player.playing:
            await ctx.send("❌ No hay nada reproduciéndose.")
            return
        if player.current.is_stream:
            await ctx.send("❌ No se puede hacer seek en transmisiones en vivo.")
            return

        try:
            if ":" in position:
                parts = position.split(":")
                if len(parts) == 2:
                    ms = (int(parts[0]) * 60 + int(parts[1])) * 1000
                elif len(parts) == 3:
                    ms = (int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])) * 1000
                else:
                    raise ValueError
            else:
                ms = int(position) * 1000
        except (ValueError, IndexError):
            await ctx.send("❌ Formato inválido. Usa segundos (`90`) o MM:SS (`1:30`).")
            return

        if ms < 0 or ms > player.current.length:
            await ctx.send(f"❌ Posición fuera de rango. La canción dura `{format_duration(player.current.length)}`.")
            return

        await player.seek(ms)
        await ctx.send(f"⏩ Saltando a `{format_duration(ms)}`")

    @commands.command(name="move", aliases=["mover"])
    async def move(self, ctx: commands.Context, from_pos: int, to_pos: int) -> None:
        """Mueve una canción de una posición a otra en la cola."""
        player = self._get_player(ctx)
        if not player or player.queue.is_empty:
            await ctx.send("❌ La cola está vacía.")
            return

        size = len(player.queue)
        if not (1 <= from_pos <= size and 1 <= to_pos <= size):
            await ctx.send(f"❌ Posiciones inválidas. La cola tiene `{size}` canciones.")
            return
        if from_pos == to_pos:
            await ctx.send("❌ Las posiciones son iguales.")
            return

        queue_list = list(player.queue)
        track = queue_list.pop(from_pos - 1)
        queue_list.insert(to_pos - 1, track)
        player.queue.clear()
        for t in queue_list:
            await player.queue.put_wait(t)

        await ctx.send(f"↕️ **{track.title}** movida de `#{from_pos}` a `#{to_pos}`.")

    @commands.command(name="lyrics", aliases=["letra"])
    async def lyrics(self, ctx: commands.Context, *, query: Optional[str] = None) -> None:
        """Muestra la letra de la canción actual (requiere plugin de Lavalink)."""
        player = self._get_player(ctx)
        current = player.current if player else None

        if not current and not query:
            await ctx.send("❌ No hay nada reproduciéndose y no proporcionaste una búsqueda.")
            return

        await ctx.send(
            "ℹ️ La función de letra requiere el plugin `lavalink-lyrics` en el servidor Lavalink. "
            "Visita: https://github.com/topi314/LavaLyrics para configurarlo."
        )

    @commands.command(name="filters", aliases=["filtros", "efectos"])
    async def filters_cmd(self, ctx: commands.Context, preset: str = "help") -> None:
        """Aplica filtros de audio. Usa 'help' para ver opciones disponibles."""
        player = self._get_player(ctx)
        if not player:
            await ctx.send("❌ No estoy en un canal de voz.")
            return

        presets = {
            "bass": "Refuerzo de graves",
            "night": "Nightcore (velocidad aumentada)",
            "slow": "Slowed (velocidad reducida)",
            "clear": "Sin filtros",
            "pop": "Ecualizador pop",
            "rock": "Ecualizador rock",
        }

        if preset.lower() == "help":
            embed = discord.Embed(title="🎚️ Filtros disponibles", color=discord.Color.blue())
            desc = "\n".join(f"`{k}` — {v}" for k, v in presets.items())
            embed.description = f"Uso: `!filters <nombre>`\n\n{desc}"
            await ctx.send(embed=embed)
            return

        filters = wavelink.Filters()

        if preset.lower() == "bass":
            filters.equalizer.set(bands=[
                {"band": 0, "gain": 0.3}, {"band": 1, "gain": 0.25},
                {"band": 2, "gain": 0.2}, {"band": 3, "gain": 0.1},
            ])
            await player.set_filters(filters)
            await ctx.send("🎚️ Filtro de graves activado.")

        elif preset.lower() == "night":
            filters.timescale.set(speed=1.25, pitch=1.15, rate=1.0)
            await player.set_filters(filters)
            await ctx.send("🌙 Filtro Nightcore activado.")

        elif preset.lower() == "slow":
            filters.timescale.set(speed=0.75, pitch=0.9, rate=1.0)
            await player.set_filters(filters)
            await ctx.send("🐢 Filtro Slowed activado.")

        elif preset.lower() == "pop":
            filters.equalizer.set(bands=[
                {"band": 0, "gain": -0.05}, {"band": 1, "gain": 0.15},
                {"band": 2, "gain": 0.2}, {"band": 3, "gain": 0.1},
                {"band": 4, "gain": 0.05},
            ])
            await player.set_filters(filters)
            await ctx.send("🎵 Filtro Pop activado.")

        elif preset.lower() == "rock":
            filters.equalizer.set(bands=[
                {"band": 0, "gain": 0.3}, {"band": 1, "gain": 0.2},
                {"band": 5, "gain": 0.1}, {"band": 6, "gain": 0.2},
                {"band": 7, "gain": 0.3},
            ])
            await player.set_filters(filters)
            await ctx.send("🎸 Filtro Rock activado.")

        elif preset.lower() == "clear":
            await player.set_filters(wavelink.Filters())
            await ctx.send("✅ Filtros eliminados.")

        else:
            await ctx.send(f"❌ Filtro desconocido: `{preset}`. Usa `!filters help` para ver opciones.")


async def setup(bot: commands.Bot) -> None:
    await bot.add_cog(Music(bot))
