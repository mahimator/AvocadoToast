"""
Simple in-memory TTL cache.

Provides bounded, time-expiring storage for catalog responses so repeated
requests for the same search query / entity are served from memory without
hitting the provider again.
"""
import threading
import time
from typing import Any, Optional


class TTLCache:
    def __init__(self, default_ttl: float = 300.0, max_items: int = 1000):
        self._default_ttl = float(default_ttl)
        self._max_items = max_items
        self._store: dict[str, tuple[float, Any]] = {}
        self._lock = threading.RLock()

    def get(self, key: str) -> Optional[Any]:
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            expiry, value = entry
            if time.monotonic() > expiry:
                del self._store[key]
                return None
            return value

    def set(self, key: str, value: Any, ttl: Optional[float] = None) -> None:
        with self._lock:
            if len(self._store) >= self._max_items and key not in self._store:
                # Evict the oldest entry (simple bounded behaviour)
                oldest = min(self._store, key=lambda k: self._store[k][0])
                del self._store[oldest]
            self._store[key] = (time.monotonic() + (ttl if ttl is not None else self._default_ttl), value)

    def delete(self, key: str) -> None:
        with self._lock:
            self._store.pop(key, None)

    def clear(self) -> None:
        with self._lock:
            self._store.clear()

    def __len__(self) -> int:
        with self._lock:
            return len(self._store)


# Shared caches keyed by endpoint/params
search_cache = TTLCache(default_ttl=300.0, max_items=500)
track_cache = TTLCache(default_ttl=86400.0, max_items=1000)
album_cache = TTLCache(default_ttl=86400.0, max_items=500)
artist_cache = TTLCache(default_ttl=43200.0, max_items=500)
playlist_cache = TTLCache(default_ttl=86400.0, max_items=500)
home_cache = TTLCache(default_ttl=900.0, max_items=50)
lyrics_cache = TTLCache(default_ttl=86400.0, max_items=1000)
charts_cache = TTLCache(default_ttl=900.0, max_items=50)

CACHE_BY_NAME = {
    "search": search_cache,
    "track": track_cache,
    "album": album_cache,
    "artist": artist_cache,
    "playlist": playlist_cache,
    "home": home_cache,
    "lyrics": lyrics_cache,
    "charts": charts_cache,
}
