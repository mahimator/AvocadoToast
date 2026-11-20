# AvocadoToast

An experimental iOS music client with a SwiftUI frontend and a small Python service adapter for YouTube Music catalog metadata.

> This is an experimental integration. `ytmusicapi` is an unofficial client for YouTube Music and is not an official playback SDK. This scaffold intentionally separates catalog metadata from media playback. It does not extract, proxy, or redistribute audio streams.

## Repository layout

- `ios/AvocadoToast/` SwiftUI app shell, navigation, search, library and mini-player UI.
- `backend/` FastAPI service wrapping the public catalog/search surface of `ytmusicapi`.
- `docs/` architecture and local development notes.

## Quick start

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn app.main:app --reload
```

### iOS

Open `ios/AvocadoToast.xcodeproj` in Xcode once the project file is generated, or create a SwiftUI iOS app target named `AvocadoToast` and add the files under `ios/AvocadoToast/`. Set `API_BASE_URL` in `AppConfig.swift` for your development machine. For a physical iPhone, use your Mac's LAN IP and ensure the device can reach the backend.

## Current scope

The initial scaffold provides a SwiftUI shell, mock-friendly API client, search and home models, and a FastAPI search adapter. Playback is deliberately represented as an interface boundary; a compliant playback provider must be chosen separately.

## Disclaimer

YouTube Music and its marks belong to Google. This project is independent and not affiliated with or endorsed by Google. Use the upstream library in accordance with its license and YouTube's terms and applicable law.