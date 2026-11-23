"""
Response normalizer.

Converts provider-specific responses (ytmusicapi) into the normalized dict
shapes expected by the iOS client (matching the APIModels Codable structs).
Every field is optionalized with .get() so provider inconsistencies never
crash the backend.
"""
from typing import Any, Dict, List, Optional

PROVIDER = "youtube_music"


def _str(v: Any, default: str = "") -> str:
    return v if isinstance(v, str) else default


def _opt_str(v: Any) -> Optional[str]:
    return v if isinstance(v, str) else None


def _int(v: Any, default: int = 0) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def _float(v: Any) -> Optional[float]:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _bool(v: Any, default: bool = False) -> bool:
    if isinstance(v, bool):
        return v
    return default


def _list(v: Any) -> List[Any]:
    return v if isinstance(v, list) else []


def _artwork(thumbnails: Any) -> Optional[str]:
    """ytmusicapi returns thumbnail lists; pick the largest available URL."""
    if not isinstance(thumbnails, list) or not thumbnails:
        return None
    # thumbnails are usually sorted small -> large; take the last
    last = thumbnails[-1]
    if isinstance(last, dict):
        return _opt_str(last.get("url"))
    return None


def _duration_seconds(item: Any) -> Optional[int]:
    # ytmusicapi may give duration_seconds or duration (mm:ss)
    if isinstance(item, dict):
        if item.get("duration_seconds") is not None:
            return _int(item.get("duration_seconds"))
        dur = _str(item.get("duration"))
        if dur:
            parts = dur.split(":")
            try:
                if len(parts) == 2:
                    return int(parts[0]) * 60 + int(parts[1])
                if len(parts) == 3:
                    return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
            except ValueError:
                pass
    return None


def normalize_search_result(item: Dict[str, Any], result_type: str = "song") -> Dict[str, Any]:
    return {
        "id": _str(item.get("videoId") or item.get("browseId") or item.get("id")),
        "provider": PROVIDER,
        "type": result_type,
        "title": _str(item.get("title")),
        "artist": _str(
            item.get("artists", [{}])[0].get("name") if isinstance(item.get("artists"), list) else ""
            or item.get("artist")
        ),
        "album": _opt_str(item.get("album") or item.get("album_name")),
        "artwork_url": _artwork(item.get("thumbnails")),
        "duration_seconds": _duration_seconds(item),
        "explicit": _bool(item.get("is_explicit")),
        "playable": True,
        "metadata": {},
        "provider_identifiers": {"videoId": item.get("videoId")} if item.get("videoId") else {},
    }


def normalize_track(item: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": _str(item.get("videoId") or item.get("id")),
        "provider": PROVIDER,
        "providerID": _str(item.get("videoId") or item.get("id")),
        "title": _str(item.get("title")),
        "artistName": _str(
            item.get("artists", [{}])[0].get("name") if isinstance(item.get("artists"), list) else ""
        ),
        "artistIDs": [a.get("id", "") for a in _list(item.get("artists")) if isinstance(a, dict)],
        "albumName": _opt_str(item.get("album") or item.get("album_name")),
        "albumID": _opt_str(item.get("albumId") or item.get("album_id")),
        "artworkURL": _artwork(item.get("thumbnails")),
        "duration": _float(_duration_seconds(item)) if _duration_seconds(item) is not None else None,
        "explicit": _bool(item.get("is_explicit")),
        "isVideo": _bool(item.get("is_video")),
        "isPlayable": True,
        "metadata": {},
        "providerIdentifiers": {"videoId": item.get("videoId")} if item.get("videoId") else {},
    }


def normalize_album(item: Dict[str, Any]) -> Dict[str, Any]:
    tracks = [normalize_track(t) for t in _list(item.get("tracks"))]
    return {
        "id": _str(item.get("browseId") or item.get("id")),
        "provider": PROVIDER,
        "providerID": _str(item.get("browseId") or item.get("id")),
        "title": _str(item.get("title")),
        "artist": _str(
            item.get("artists", [{}])[0].get("name") if isinstance(item.get("artists"), list) else ""
        ),
        "artistIDs": [a.get("id", "") for a in _list(item.get("artists")) if isinstance(a, dict)],
        "artworkURL": _artwork(item.get("thumbnails")),
        "releaseDate": _opt_str(item.get("year") or item.get("release_date")),
        "trackCount": _int(item.get("trackCount") or len(tracks)),
        "albumType": _str(item.get("albumType") or item.get("album_type") or "album"),
        "tracks": tracks,
        "metadata": {},
        "providerIdentifiers": {},
    }


def normalize_artist(item: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": _str(item.get("browseId") or item.get("id")),
        "provider": PROVIDER,
        "providerID": _str(item.get("browseId") or item.get("id")),
        "name": _str(item.get("name") or item.get("artist")),
        "artworkURL": _artwork(item.get("thumbnails")),
        "description": _opt_str(item.get("description")),
        "genres": [g for g in _list(item.get("genres")) if isinstance(g, str)],
        "albums": [normalize_album(a) for a in _list(item.get("albums"))],
        "singles": [normalize_album(a) for a in _list(item.get("singles"))],
        "topTracks": [normalize_track(t) for t in _list(item.get("topTracks"))],
        "relatedArtists": [normalize_artist(a) for a in _list(item.get("related"))],
        "metadata": {},
        "providerIdentifiers": {},
    }


def normalize_playlist(item: Dict[str, Any]) -> Dict[str, Any]:
    tracks = [normalize_track(t) for t in _list(item.get("tracks"))]
    return {
        "id": _str(item.get("playlistId") or item.get("browseId") or item.get("id")),
        "provider": PROVIDER,
        "providerID": _str(item.get("playlistId") or item.get("browseId") or item.get("id")),
        "title": _str(item.get("title") or item.get("name")),
        "description": _opt_str(item.get("description")),
        "artworkURL": _artwork(item.get("thumbnails")),
        "creator": _str(item.get("creator") or item.get("author")),
        "trackCount": _int(item.get("trackCount") or len(tracks)),
        "tracks": tracks,
        "isEditable": False,
        "metadata": {},
        "providerIdentifiers": {},
    }


def normalize_home_section(title: str, items: List[Dict[str, Any]], section_id: str) -> Dict[str, Any]:
    entities = []
    for it in items:
        t = _str(it.get("title") or it.get("name"))
        sub = _str(it.get("subtitle") or it.get("artist") or "")
        entities.append(
            {
                "id": _str(it.get("videoId") or it.get("browseId") or it.get("id")),
                "provider": PROVIDER,
                "entityType": _str(it.get("type") or "song"),
                "title": t,
                "subtitle": sub,
                "artwork": _artwork(it.get("thumbnails")),
                "metadata": {},
                "providerIdentifiers": {},
            }
        )
    return {
        "id": section_id,
        "title": title,
        "type": "mixed",
        "items": entities,
    }
