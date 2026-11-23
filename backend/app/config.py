"""
Application configuration.
Configuration is driven by environment variables with safe defaults.
No secrets are hardcoded.
"""
import os
from functools import lru_cache


def _env(name: str, default: str) -> str:
    return os.environ.get(name, default)


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, str(default)))
    except (TypeError, ValueError):
        return default


def _env_float(name: str, default: float) -> float:
    try:
        return float(os.environ.get(name, str(default)))
    except (TypeError, ValueError):
        return default


def _env_bool(name: str, default: bool) -> bool:
    return os.environ.get(name, str(default)).lower() in ("1", "true", "yes", "on")


class Settings:
    APP_ENV: str = _env("APP_ENV", "development")
    API_HOST: str = _env("API_HOST", "0.0.0.0")
    API_PORT: int = _env_int("API_PORT", 8000)
    LOG_LEVEL: str = _env("LOG_LEVEL", "info")

    # Cache TTLs (seconds)
    CACHE_TTL_SEARCH: int = _env_int("CACHE_TTL_SEARCH", 300)
    CACHE_TTL_TRACK: int = _env_int("CACHE_TTL_TRACK", 86400)
    CACHE_TTL_ALBUM: int = _env_int("CACHE_TTL_ALBUM", 86400)
    CACHE_TTL_ARTIST: int = _env_int("CACHE_TTL_ARTIST", 43200)
    CACHE_TTL_HOME: int = _env_int("CACHE_TTL_HOME", 900)
    CACHE_TTL_LYRICS: int = _env_int("CACHE_TTL_LYRICS", 86400)

    # Provider
    PROVIDER_TIMEOUT: float = _env_float("PROVIDER_TIMEOUT", 15.0)
    PROVIDER_MAX_CONCURRENCY: int = _env_int("PROVIDER_MAX_CONCURRENCY", 5)

    @property
    def is_development(self) -> bool:
        return self.APP_ENV == "development"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
