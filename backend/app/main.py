from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import router as v1_router
from app.config import get_settings

settings = get_settings()

app = FastAPI(
    title="Avocado Toast Catalog API",
    version="1.0.0",
    description="Backend catalog service for Avocado Toast iOS app (FastAPI + ytmusicapi)",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(v1_router, prefix="/api/v1")


@app.get("/health", tags=["health"], include_in_schema=False)
async def root_health():
    return {"status": "ok"}


@app.on_event("shutdown")
async def _shutdown():
    # ytmusicapi holds no persistent connections; nothing to close here.
    pass
