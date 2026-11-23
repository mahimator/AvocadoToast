# Avocado Toast Rebuild Notes

Branch: `fuhahh-try`

## Product direction
Native SwiftUI iPhone music discovery and listening app. The app keeps its own warm espresso, avocado, butter and toast identity. The fullscreen player is a separate listening room whose ambient light is sampled from the current artwork.

Catalog metadata and playback are separate concepts. The YouTube Music integration is unofficial and may break or be restricted. Do not imply that catalog metadata access grants permission to play or download audio.

## Implemented in this rebuild pass
- Home discovery, featured song, recently played, mood search shortcuts, refresh and search launcher.
- Search categories for songs, albums, artists and playlists, with debouncing, cancellation, persistent recent searches, empty/loading/error states and stale-result protection.
- Album and artist detail entry points, direct browse for provider IDs when available, and queue-aware track selection.
- Actual playlist browsing with continuation pagination, duplicate-ID protection and page-count bounds.
- Shared player state with play/pause, seek, next/previous, shuffle, repeat-one/repeat-all, queue sheet, Play All, Add to Queue and Play Next.
- Lock Screen / headset / car commands and Now Playing metadata, including artwork and position.
- Background audio, AirPlay route selection, interruption handling and pausing when personal audio is unplugged.
- Lyrics/captions sheet with timed active line, auto-scroll and tap-to-seek.
- Saved tracks, separate recent-play history, album/artist collections and local playlists.
- Local playlist create, rename, add/remove songs, reorder and Play All.
- Multi-file local audio import through the iOS file picker, metadata and embedded artwork extraction, sandboxed file storage, local playback, and safe cleanup.
- Artwork memory/disk caching, artwork-derived ambience, reduced-motion behavior, light/dark/system palette and the glass-effects preference.
- Shared SwiftData persistence context and local-library reset.
- GitHub Actions simulator compilation.

## Deliberate non-goals
- Downloading catalog streams for offline playback.
- DRM/content-protection circumvention.
- Commercial licensing, billing, social messaging, uploads, audio editing, desktop/Android clients or a custom recommendation model.
- Controls for features that are not actually wired.

## Architecture notes
- SwiftUI screens consume shared observable services rather than maintaining separate playback state.
- Catalog service owns search and queue transitions.
- AudioPlayerService owns AVPlayer/AVAudioEngine, the audio session and system remote commands.
- LibraryService owns SwiftData library and history operations.
- LocalAudioManager only imports and manages user-provided files. It is not a catalog downloader.
- ArtworkService handles remote and sandbox-file images.

## Verification
GitHub Actions builds the iOS Simulator target. A green simulator build validates compilation only. Physical-device audio, AirPlay, Lock Screen, captions, file import, accessibility and UI appearance still require hands-on verification. Third-party InnerTube behavior is not guaranteed.
