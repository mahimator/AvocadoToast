# Avocado Toast: Product and Implementation SRS

## 1. Product
Avocado Toast is a native iOS music discovery and listening app. The visual identity is warm, playful and cozy, built around espresso, avocado, butter and toast colors. It should feel like a small listening room, not a sterile black music utility.

The main navigation stays intentionally small:
1. **Listen** for discovery and recent activity.
2. **Search** for songs, albums, artists and playlists.
3. **Library** for saved music, history and user-created playlists.
4. **Settings** for only meaningful preferences and storage actions.

The fullscreen Now Playing surface is a separate immersive layer. Its ambient light is derived from the current track artwork, with a safe warm fallback.

## 2. Goals
- G1: Discover music using a simple home feed and typed search.
- G2: Provide an elegant native iOS interface using SwiftUI and Liquid Glass where appropriate.
- G3: Save music, create/edit playlists, import local audio, and retain listening history.
- G4: Provide coherent queue and playback controls.
- G5: Integrate native audio session behavior, background playback, AirPlay, and Lock Screen controls.
- G6: Keep the catalog/playback provider boundary replaceable and fail honestly when a source is unavailable.

## 3. Main flows
### Listen
- Search entry point, featured track, recently played, discovery results, mood shortcuts.
- Home sections load from catalog search and local history.
- Refresh reloads discovery.

### Search
- Search categories: songs, albums, artists, playlists.
- Typing is debounced. Requests are cancelled when the query is cleared or superseded.
- Recent searches are persisted and replay in the selected category.
- Results have loading, empty, and error states.
- Artist, album and playlist rows navigate to detail.

### Library
- Saved songs are distinct from listening history.
- Saved songs play and can be removed.
- Albums and artists are browseable when their provider IDs are available.
- Recent tracks remain separate from saved favorites.
- Local playlists support create, rename, add/remove tracks, reordering and Play All.
- Local audio files can be imported from Files. Import copies into the app sandbox, validates the file, reads basic metadata and embedded artwork, and allows playback. Removing an imported track deletes its owned audio and artwork files.

### Player
- One shared player state is used across the app.
- Mini-player and fullscreen Now Playing reflect actual player state.
- Controls: play/pause, seek, next, previous, shuffle, repeat off/all/one, queue list.
- Play All creates a queue. Search and featured tracks support Add to Queue and Play Next.
- Lyrics/captions, when available, are shown with active-line focus, scrolling and tap-to-seek.

### iOS audio
- AVPlayer handles valid remote URLs; AVAudioEngine handles user-imported local files and the local EQ processing path.
- Background audio capability is enabled.
- Lock Screen and headset/car remote commands update the shared queue.
- Audio interruptions are handled and playback pauses when personal audio is disconnected.
- AirPlay route selection uses the native route picker.

## 4. Architecture
- **SwiftUI** for UI.
- **CatalogService** for search state, queue state and playback transitions.
- **YouTubeKitService** for catalog/provider calls and metadata parsing.
- **AudioPlayerService** for AVPlayer/AVAudioEngine, progress, audio session, system commands and playback completion.
- **LibraryService** for SwiftData saved music, playlists and listening history.
- **LocalAudioManager** for user-imported audio files only. It does not download catalog streams.
- **ArtworkService** for remote/file artwork caching and color sampling.
- **AppConfig / ColorTokens** for persisted appearance, glass and motion preferences.

No backend or desktop companion is required for this branch.

## 5. Data and persistence
- SwiftData is the source of truth for saved tracks, albums, artists, local playlists and recent history.
- The queue and repeat/shuffle state are transient playback state.
- Imported audio and artwork are stored inside the app's Documents sandbox.
- Library reset clears saved records, recent history and imported audio.

## 6. UI design rules
- Avocado Toast theme remains consistent across home, search, library, settings and mini-player.
- Now Playing adapts its ambient color to artwork without compromising text/control contrast.
- Glass is used for hierarchy and controls, not every surface.
- Reduced Motion disables or softens motion-heavy transitions.
- Empty/loading/error states must be honest and helpful.
- No decorative control should exist without a real action.

## 7. Non-goals
- Catalog-stream offline downloading.
- DRM or content-protection circumvention.
- Commercial licensing, payments, social messaging, uploads, audio editing, desktop or Android clients.
- Custom codecs, CDNs or proprietary recommendation models.
- Fake playback controls or mock data presented as live catalog results.

## 8. Known provider constraints
YouTube Music / InnerTube is an unofficial integration. Search, playlist browse, captions and source resolution may break, be restricted, or behave differently across accounts and regions. Provider integration must be replaceable. Catalog metadata availability does not itself establish permission to play or download media.

## 9. Verification
- GitHub Actions compiles the iOS Simulator target on macOS.
- Simulator compilation is not a substitute for physical-device validation.
- On-device testing remains required for audio, background mode, AirPlay, Lock Screen commands, interruptions, file importing, accessibility, performance and visual layout.
- No dedicated XCTest target is currently configured.
