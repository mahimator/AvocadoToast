from fastapi import APIRouter

from app.services.catalog_service import home

router = APIRouter()


@router.get("/home", tags=["home"])
async def get_home():
    return await home()
