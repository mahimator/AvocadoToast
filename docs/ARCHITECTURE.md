# Architecture

## First experiment

- **iOS:** SwiftUI owns navigation, presentation, search state, and library UI.
- **API:** FastAPI provides a narrow typed boundary to the upstream Python client.
- **Catalog:** `ytmusicapi` is used for search metadata only.
- **Playback:** `PlayerStore` is an intentional provider boundary. The unofficial API is not treated as a supported native playback SDK. This scaffold does not extract or relay streams.

## Data flow

1. SwiftUI requests `GET /v1/search?q=...`.
2. FastAPI calls `YTMusic.search(..., filter="songs")`.
3. The API maps upstream data into the stable `Track` schema.
4. The app presents results and can select a track in the mini-player UI.

## Next milestones

1. Generate and check in a real Xcode project, app icon, and signing configuration.
2. Add local persistence for saved tracks and playlists.
3. Add pagination, request cancellation, and caching.
4. Choose a playback provider with rights and platform support appropriate to the intended use.
5. Add tests and per-environment API configuration.