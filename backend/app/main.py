from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from ytmusicapi import YTMusic

app = FastAPI(title="AvocadoToast API", version="0.1.0")

# Development convenience only. Restrict origins before deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "avocadotoast-api"}


@app.get("/v1/search")
def search_tracks(q: str = Query(min_length=1, max_length=120)) -> list[dict]:
    """Search public catalog metadata; no media stream URLs are returned."""
    try:
        items = YTMusic().search(q, filter="songs", limit=20)
    except Exception as exc:
        raise HTTPException(status_code=502, detail="YouTube Music catalog search failed") from exc

    tracks = []
    for item in items:
        video_id = item.get("videoId")
        if not video_id:
            continue
        artists = item.get("artists") or []
        thumbnails = item.get("thumbnails") or []
        tracks.append({
            "video_id": video_id,
            "title": item.get("title") or "Unknown title",
            "artist": ", ".join(a.get("name", "") for a in artists if a.get("name")) or "Unknown artist",
            "album": (item.get("album") or {}).get("name"),
            "thumbnail_url": thumbnails[-1].get("url") if thumbnails else None,
            "duration": item.get("duration"),
        })
    return tracks