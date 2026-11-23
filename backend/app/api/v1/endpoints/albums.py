from fastapi import APIRouter

from app.services.catalog_service import get_album as fetch_album

router = APIRouter()


@router.get("/albums/{album_id}", tags=["albums"])
async def get_album_endpoint(album_id: str):
    return await fetch_album(album_id)
