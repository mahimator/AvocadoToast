from fastapi import APIRouter

from app.services.catalog_service import get_charts

router = APIRouter()


@router.get("/charts", tags=["charts"])
async def get_charts_endpoint():
    return await get_charts()
