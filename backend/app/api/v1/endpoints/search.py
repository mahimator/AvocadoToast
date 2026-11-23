from typing import Optional

from fastapi import APIRouter, Query

from app.services.catalog_service import search

router = APIRouter()


@router.get("/search", tags=["search"])
async def get_search(
    q: str = Query(..., min_length=1, description="Search query"),
    type: Optional[str] = Query(None, description="songs|videos|albums|artists|playlists|all"),
    limit: int = Query(20, ge=1, le=50, description="Max results"),
):
    return await search(query=q, type_filter=type, limit=limit)
