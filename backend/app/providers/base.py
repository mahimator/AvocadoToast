"""
Provider interface.
All catalog providers implement this interface so the backend can swap or
add providers without changing the API layer.
"""
from typing import Any, List, Optional


class ProviderError(Exception):
    """Raised when a provider fails."""


class BaseProvider:
    name: str = "base"

    async def health(self) -> dict:
        raise NotImplementedError

    async def search(self, query: str, type_filter: Optional[str] = None, limit: int = 20) -> dict:
        raise NotImplementedError

    async def get_track(self, track_id: str) -> dict:
        raise NotImplementedError

    async def get_album(self, album_id: str) -> dict:
        raise NotImplementedError

    async def get_artist(self, artist_id: str) -> dict:
        raise NotImplementedError

    async def get_playlist(self, playlist_id: str) -> dict:
        raise NotImplementedError

    async def get_related(self, track_id: str) -> List[dict]:
        raise NotImplementedError

    async def get_lyrics(self, track_id: str) -> dict:
        raise NotImplementedError

    async def get_charts(self) -> dict:
        raise NotImplementedError
