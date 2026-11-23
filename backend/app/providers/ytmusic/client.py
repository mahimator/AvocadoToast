"""
ytmusicapi client wrapper.

ytmusicapi is synchronous and unofficial. We run its calls in a thread pool
so the FastAPI event loop stays responsive, and map errors into ProviderError.
"""
import asyncio
from typing import Any, Callable, Dict, List, Optional

from ytmusicapi import YTMusic
from ytmusicapi.exceptions import YTMusicError

from app.providers.base import BaseProvider, ProviderError

# Shared YTMusic instance (ytmusicapi is safe to reuse for read-only calls)
_ytmusic: Optional[YTMusic] = None


def _get_ytmusic() -> YTMusic:
    global _ytmusic
    if _ytmusic is None:
        _ytmusic = YTMusic()
    return _ytmusic


def _safe_call(func: Callable, *args, **kwargs) -> Any:
    """Run a ytmusicapi call, converting StopIteration (gen/Py3.9 asyncio issue)
    and provider errors into ProviderError."""
    try:
        return func(*args, **kwargs)
    except StopIteration:
        return None
    except YTMusicError as exc:
        raise ProviderError(str(exc)) from exc
    except Exception as exc:  # pragma: no cover - defensive
        raise ProviderError(f"provider error: {exc}") from exc


class YTMusicProvider(BaseProvider):
    name = "youtube_music"

    def __init__(self, timeout: float = 15.0):
        self.timeout = timeout

    async def _run(self, func: Callable, *args, **kwargs) -> Any:
        loop = asyncio.get_event_loop()
        try:
            return await asyncio.wait_for(
                loop.run_in_executor(None, lambda: _safe_call(func, *args, **kwargs)),
                timeout=self.timeout,
            )
        except asyncio.TimeoutError as exc:
            raise ProviderError("provider timeout") from exc

    async def health(self) -> dict:
        # Just confirm we can construct the client; a bogus get_song raises,
        # which is fine (provider reachable).
        try:
            await self._run(_get_ytmusic().get_song, "does-not-exist")
        except ProviderError:
            pass
        return {"status": "ok", "provider": self.name}

    async def search(self, query: str, type_filter: Optional[str] = None, limit: int = 20) -> dict:
        from app.providers.ytmusic.normalizer import normalize_search_result

        def _search() -> dict:
            category = "songs"
            if type_filter in ("albums", "artists", "playlists", "videos"):
                category = type_filter
            raw = _get_ytmusic().search(query, filter=category, limit=limit) or []
            results = [normalize_search_result(item, result_type=item.get("category", "song")) for item in raw]
            return {"query": query, "category": category, "results": results}

        return await self._run(_search)

    async def get_track(self, track_id: str) -> dict:
        from app.providers.ytmusic.normalizer import normalize_track

        def _get() -> dict:
            item = _get_ytmusic().get_song(track_id) or {}
            return normalize_track(item)

        return await self._run(_get)

    async def get_album(self, album_id: str) -> dict:
        from app.providers.ytmusic.normalizer import normalize_album

        def _get() -> dict:
            item = _get_ytmusic().get_album(album_id) or {}
            return normalize_album(item)

        return await self._run(_get)

    async def get_artist(self, artist_id: str) -> dict:
        from app.providers.ytmusic.normalizer import normalize_artist

        def _get() -> dict:
            item = _get_ytmusic().get_artist(artist_id) or {}
            return normalize_artist(item)

        return await self._run(_get)

    async def get_playlist(self, playlist_id: str) -> dict:
        from app.providers.ytmusic.normalizer import normalize_playlist

        def _get() -> dict:
            item = _get_ytmusic().get_playlist(playlist_id) or {}
            return normalize_playlist(item)

        return await self._run(_get)

    async def get_related(self, track_id: str) -> List[dict]:
        from app.providers.ytmusic.normalizer import normalize_search_result

        def _get() -> List[dict]:
            raw = _get_ytmusic().get_watch_playlist(track_id) or {}
            tracks = raw.get("tracks", []) or []
            return [normalize_search_result(t, result_type="song") for t in tracks[:10]]

        return await self._run(_get)

    async def get_lyrics(self, track_id: str) -> dict:
        def _get() -> dict:
            try:
                item = _get_ytmusic().get_lyrics(track_id) or {}
            except YTMusicError:
                item = {}
            return {
                "trackID": track_id,
                "lyrics": item.get("lyrics") if isinstance(item, dict) else None,
                "hasLyrics": bool((item or {}).get("lyrics")),
            }

        return await self._run(_get)

    async def get_charts(self) -> dict:
        from app.providers.ytmusic.normalizer import normalize_search_result

        def _get() -> dict:
            raw = _get_ytmusic().get_charts() or {}
            categories = []
            for cat_name, items in raw.items():
                items_list = items if isinstance(items, list) else []
                categories.append(
                    {
                        "id": str(cat_name),
                        "title": str(cat_name).replace("_", " ").title(),
                        "items": [
                            {
                                "id": str(t.get("videoId") or t.get("id") or ""),
                                "provider": "youtube_music",
                                "entityType": str(t.get("category", "song")),
                                "title": str(t.get("title") or ""),
                                "subtitle": _artist_subtitle(t),
                                "artwork": _thumb_url(t),
                                "metadata": {},
                                "providerIdentifiers": {},
                            }
                            for t in items_list[:10]
                        ],
                    }
                )
            return {"charts": categories}

        return await self._run(_get)


def _artist_subtitle(item: Any) -> str:
    if isinstance(item, dict):
        artists = item.get("artists")
        if isinstance(artists, list) and artists:
            a0 = artists[0]
            if isinstance(a0, dict):
                return str(a0.get("name") or "")
    return ""


def _thumb_url(item: Any) -> Optional[str]:
    if isinstance(item, dict):
        thumbs = item.get("thumbnails")
        if isinstance(thumbs, list) and thumbs:
            last = thumbs[-1]
            if isinstance(last, dict):
                return last.get("url")
    return None
