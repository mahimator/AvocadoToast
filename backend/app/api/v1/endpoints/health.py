from fastapi import APIRouter

from app.services.catalog_service import health

router = APIRouter()


@router.get("/health", tags=["health"])
async def get_health():
    return await health()
