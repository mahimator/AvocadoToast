from fastapi import APIRouter

from app.api.v1.endpoints import albums, artists, charts, health, home, playlists, search, songs

router = APIRouter()

# Each endpoint router already defines its full path (e.g. "/search"), so we
# mount them directly under /api/v1 without an additional prefix.
router.include_router(search.router, tags=["search"])
router.include_router(home.router, tags=["home"])
router.include_router(songs.router, tags=["songs"])
router.include_router(albums.router, tags=["albums"])
router.include_router(artists.router, tags=["artists"])
router.include_router(playlists.router, tags=["playlists"])
router.include_router(charts.router, tags=["charts"])
router.include_router(health.router, tags=["health"])
