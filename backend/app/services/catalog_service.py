"""
Catalog service.

Orchestrates provider access with caching and graceful degradation.
If the provider is unavailable, endpoints return empty/error responses
rather than crashing the client.
"""
import asyncio
from typing import Any, Dict, List, Optional

from app.config import get_settings
from app.services.cache_service import (
    album_cache, artist_cache, charts_cache, home_cache, lyrics_cache,
    playlist_cache, search_cache, track_cache,
)
from app.providers.base import ProviderError
from app.providers.ytmusic.client import YTMusicProvider

# Singleton provider
_provider: Optional[YTMusicProvider] = None
_provider_lock = asyncio.Lock()


async def get_provider() -> YTMusicProvider:
    global _provider
    if _provider is None:
        async with _provider_lock:
            if _provider is None:
                settings = get_settings()
                _provider = YTMusicProvider(timeout=settings.PROVIDER_TIMEOUT)
    return _provider


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------
async def search(query: str, type_filter: Optional[str] = None, limit: int = 20) -> Dict[str, Any]:
    settings = get_settings()
    cache_key = f"search:{query}:{type_filter}:{limit}"
    cached = search_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        provider = await get_provider()
        result = await provider.search(query, type_filter=type_filter, limit=limit)
    except ProviderError:
        result = {"query": query, "category": type_filter or "songs", "results": []}
    search_cache.set(cache_key, result, ttl=settings.CACHE_TTL_SEARCH)
    return result


# ---------------------------------------------------------------------------
# Home
# ---------------------------------------------------------------------------
async def home() -> Dict[str, Any]:
    settings = get_settings()
    cached = home_cache.get("home")
    if cached is not None:
        return cached
    try:
        provider = await get_provider()
        result = await _build_home(provider)
    except ProviderError:
        result = {"sections": []}
    home_cache.set("home", result, ttl=settings.CACHE_TTL_HOME)
    return result


async def _build_home(provider) -> Dict[str, Any]:
    # Build a home page from charts + a few featured searches without
    # requiring multiple provider round trips.
    charts = await provider.get_charts()
    charts = charts or {"charts": []}
    sections: List[Dict[str, Any]] = []
    for cat in charts.get("charts", [])[:6]:
        sections.append(
            {
                "id": cat.get("id", "home"),
                "title": cat.get("title", "Charts"),
                "type": "mixed",
                "items": cat.get("items", []),
            }
        )
    # Always include a generic "Top charts" section even if empty
    if not sections:
        sections.append({"id": "top", "title": "Top Charts", "type": "mixed", "items": []})
    return {"sections": sections}


# ---------------------------------------------------------------------------
# Entities
# ---------------------------------------------------------------------------
async def get_track(track_id: str) -> Dict[str, Any]:
    settings = get_settings()
    cache_key = f"track:{track_id}"
    cached = track_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        provider = await get_provider()
        result = await provider.get_track(track_id)
    except ProviderError:
        result = {}
    track_cache.set(cache_key, result, ttl=settings.CACHE_TTL_TRACK)
    return result


async def get_album(album_id: str) -> Dict[str, Any]:
    settings = get_settings()
    cache_key = f"album:{album_id}"
    cached = album_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        provider = await get_provider()
        result = await provider.get_album(album_id)
    except ProviderError:
        result = {}
    album_cache.set(cache_key, result, ttl=settings.CACHE_TTL_ALBUM)
    return result


async def get_artist(artist_id: str) -> Dict[str, Any]:
    settings = get_settings()
    cache_key = f"artist:{artist_id}"
    cached = artist_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        provider = await get_provider()
        result = await provider.get_artist(artist_id)
    except ProviderError:
        result = {}
    artist_cache.set(cache_key, result, ttl=settings.CACHE_TTL_ARTIST)
    return result


async def get_playlist(playlist_id: str) -> Dict[str, Any]:
    settings = get_settings()
    cache_key = f"playlist:{playlist_id}"
    cached = playlist_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        provider = await get_provider()
        result = await provider.get_playlist(playlist_id)
    except ProviderError:
        result = {}
    playlist_cache.set(cache_key, result, ttl=settings.CACHE_TTL_PLAYLIST)
    return result


async def get_related(track_id: str) -> List[Dict[str, Any]]:
    try:
        provider = await get_provider()
        return await provider.get_related(track_id)
    except ProviderError:
        return []


async def get_lyrics(track_id: str) -> Dict[str, Any]:
    settings = get_settings()
    cache_key = f"lyrics:{track_id}"
    cached = lyrics_cache.get(cache_key)
    if cached is not None:
        return cached
    try:
        provider = await get_provider()
        result = await provider.get_lyrics(track_id)
    except ProviderError:
        result = {"trackID": track_id, "lyrics": None, "hasLyrics": False}
    lyrics_cache.set(cache_key, result, ttl=settings.CACHE_TTL_LYRICS)
    return result


async def get_charts() -> Dict[str, Any]:
    settings = get_settings()
    cached = charts_cache.get("charts")
    if cached is not None:
        return cached
    try:
        provider = await get_provider()
        result = await provider.get_charts() or {"charts": []}
    except ProviderError:
        result = {"charts": []}
    charts_cache.set("charts", result, ttl=settings.CACHE_TTL_HOME)
    return result


async def health() -> Dict[str, Any]:
    try:
        provider = await get_provider()
        return await provider.health()
    except ProviderError:
        return {"status": "degraded", "provider": "youtube_music"}
