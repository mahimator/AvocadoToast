from fastapi import APIRouter

from app.services.catalog_service import get_playlist as fetch_playlist

router = APIRouter()


@router.get("/playlists/{playlist_id}", tags=["playlists"])
async def get_playlist_endpoint(playlist_id: str):
    return await fetch_playlist(playlist_id)
