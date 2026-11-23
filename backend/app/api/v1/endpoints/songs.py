from fastapi import APIRouter

from app.services.catalog_service import get_lyrics, get_related, get_track

router = APIRouter()


@router.get("/songs/{track_id}", tags=["songs"])
async def get_song(track_id: str):
    return await get_track(track_id)


@router.get("/songs/{track_id}/related", tags=["songs"])
async def get_song_related(track_id: str):
    return await get_related(track_id)


@router.get("/songs/{track_id}/lyrics", tags=["songs"])
async def get_song_lyrics(track_id: str):
    return await get_lyrics(track_id)
