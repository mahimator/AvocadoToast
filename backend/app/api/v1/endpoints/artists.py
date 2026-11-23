from fastapi import APIRouter

from app.services.catalog_service import get_artist as fetch_artist

router = APIRouter()


@router.get("/artists/{artist_id}", tags=["artists"])
async def get_artist_endpoint(artist_id: str):
    return await fetch_artist(artist_id)
