# Avocado Toast SRS - Structured Implementation Summary

## Product Overview
- **Product**: Avocado Toast - music discovery and listening application for iOS
- **Codename**: Avocado Toast
- **Target**: iOS native application with Swift/SwiftUI
- **Backend**: Python/FastAPI
- **Music provider**: ytmusicapi (unofficial Python library)
- **Design**: Liquid Glass inspired interface
- **Architecture**: MVVM with service/repository separation

## Primary Goals (G1-G6)
- G1: Music discovery (search songs, artists, albums, playlists)
- G2: Premium native interface (Liquid Glass, immersive)
- G3: Unified music library (save, organise, manage)
- G4: Functional player architecture (playback state, queue, controls)
- G5: Reliable metadata infrastructure (backend abstraction over ytmusicapi)
- G6: Expandability (support additional providers later)

## Non-Goals (Initial Release)
- No commercial licensing, DRM, billing, social networking, user messaging
- No desktop client, Android support
- No artist uploads, music production, audio editing
- No offline downloading, audio stream extraction
- No circumvention of content protection
- No proprietary recommendation model, custom codec, custom CDN

## Technology Stack

### iOS Client
- Language: Swift
- UI: SwiftUI
- Architecture: MVVM with service/repository separation
- Animation: SwiftUI animation system, spring animation
- Glass effects: Native Liquid Glass with fallbacks
- Networking: URLSession
- JSON: Codable
- State management: Observable state/Observation
- Persistence: SwiftData or isolated persistence abstraction
- Images: Async image loading/caching
- Navigation: Native SwiftUI navigation
- Audio: AVFoundation
- Minimum deployment: To be confirmed

### Backend
- Runtime: Python 3.11+
- Framework: FastAPI
- API: REST/JSON
- Music provider: ytmusicapi
- Validation: Pydantic
- HTTP client: HTTPX
- Testing: Pytest
- Logging: Python logging
- Configuration: Environment variables
- Deployment: Container or managed Python host

## Architecture

### Navigation Destinations
1. Home - discovery, recommendations, recent activity
2. Search - music catalog search
3. Library - saved music and collections
4. Now Playing - expanded player layer (accessible via mini-player)

### Data Flow
- Frontend should NOT directly communicate with ytmusicapi
- All catalog access goes through backend
- Backend normalizes provider data, handles errors, caches results

## Design & User Experience

### Liquid Glass Design Language
- Glass surfaces: translucent glass, background blur, light reflection, subtle edge highlights, depth separation, soft shadows, glass layering, gradient illumination, background colour influence, dynamic opacity, contextual tinting, glass overlays on artwork, floating glass controls, glass navigation surfaces
- Surface hierarchy:
  - Layer 1: Ambient environment (background gradient, artwork colour, ambient light)
  - Layer 2: Content (album art, lists, text)
  - Layer 3: Glass (floating player, tab bar, controls)
  - Layer 4: Interaction (buttons, sliders, menus)
- Rules: Glass readable, sufficient contrast, artwork not obscured, controls recognizable, motion not unnecessary, state transitions, adapt to dynamic backgrounds, float within interface

### Colour System
- Tokens: backgroundPrimary, backgroundSecondary, surfaceGlass, surfaceElevated, textPrimary, textSecondary, accentPrimary, accentMuted, separator, playerProgress
- Artwork-driven atmosphere: currently displayed artwork may influence background gradients, ambient glow, player tint, accent colour, mini-player appearance (must be subtle, controlled)

### Navigation
- Main destinations: Home, Search, Library
- Now Playing via mini-player, track selection, queue selection, contextual actions
- Floating/elevated glass tab bar
- Tab switching preserves state, doesn't reset scroll positions
- Player persists across tab transitions
- Mini-player available everywhere

## Screen Specifications

### Home Screen (26.1)
- Structure: Top area (identity, greeting, profile), Search entry, Recently played, Featured music, Discover/recommendations, Album collections, Artist discovery, Playlist discovery, Floating mini-player
- Acceptance: Opens without waiting for all sections, independent section loading, prominent artwork, horizontal carousels, tap navigation, player accessible, refresh support, offline/failed state, cached content

### Search Screen (26.2)
- Structure: Search field (query, clear, suggestions), Category selector (All, Songs, Artists, Albums, Playlists), Search results, Mini-player
- Acceptance: Text input, clear, debounced requests, cancel, category filtering, scrollable results, contextual actions, loading/empty/error states, late responses don't overwrite newer results

### Library Screen (26.3)
- Structure: Header, Library filters (Songs, Albums, Artists, Playlists), Saved content, Recently played, Mini-player
- Acceptance: Persists after restart, remove items, filters function, intentional empty display, doesn't require YouTube Music login, identifiable even if remote metadata unavailable

### Mini-player (26.4)
- Persistent floating layer above navigation
- Contents: Artwork, title, artist, play/pause, progress indication, expand interaction
- Acceptance: Appears when player state warrants, visible across tabs, tap to expand, reflects playback state, artwork stable, doesn't obstruct tab bar/safe area

### Now Playing (26.5)
- Layout: Dynamic ambient background, Top navigation glass (Collapse, More), Album artwork, Track title, Artist, Playback progress, Primary controls (Previous, Play/Pause, Next), Secondary controls (Shuffle, Repeat, Queue, Lyrics), Queue/contextual content
- Acceptance: Animated expansion/collapse, controls reflect state, seek reflects engine, unsupported handled honestly, artwork focus, readable background

### Settings (26.6)
- Structure: Appearance, Motion, Search, Library, Cache, About, Version, Backend connection, Debug (development builds)
- Must not become dumping ground for unrelated controls

## API Specification

### Endpoints
- GET /api/v1/health - Backend health
- GET /api/v1/search?q=... - Catalog search (params: q, type, limit, continuation)
- GET /api/v1/home - Discovery content
- GET /api/v1/songs/{id} - Song metadata
- GET /api/v1/albums/{id} - Album details
- GET /api/v1/artists/{id} - Artist details
- GET /api/v1/playlists/{id} - Playlist details
- GET /api/v1/songs/{id}/related - Related music
- GET /api/v1/songs/{id}/lyrics - Lyrics
- GET /api/v1/charts - Catalog charts

### Search Response
```json
{
  "query": "Kendrick Lamar",
  "category": "songs",
  "results": [
    {
      "id": "provider-video-id",
      "provider": "youtube_music",
      "type": "song",
      "title": "Example Song",
      "artist": "Kendrick Lamar",
      "album": "Example Album",
      "artwork_url": "https://example.com/artwork.jpg",
      "duration_seconds": 245,
      "explicit": null,
      "playable": false
    }
  ],
  "next_page": null
}
```

### Unified Music Entity (Data Model)
```swift
MusicEntity {
    id: String
    provider: String
    entityType: String
    title: String
    subtitle: String
    artwork: URL?
    metadata: Dictionary
    providerIdentifiers: Dictionary
}
```

### Track Model
```swift
Track {
    id: String (stable internal ID)
    provider: String
    providerID: String (original provider identifier)
    title: String
    artistName: String
    artistIDs: Array
    albumName: String?
    albumID: String?
    artworkURL: URL?
    duration: Double?
    explicit: Bool?
    isVideo: Bool
    isPlayable: Bool
    addedAt: Date?
    lastPlayedAt: Date?
    playCount: Int
    metadata: Dictionary
}
```

### Artist Model
```swift
Artist {
    id, provider, providerID, name, artworkURL, description, genres, albums, singles, topTracks, relatedArtists
}
```

### Album Model
```swift
Album {
    id, provider, providerID, title, artist, artworkURL, releaseDate, trackCount, albumType, tracks
}
```

### Playlist Model
```swift
Playlist {
    id, provider, providerID, title, description, artworkURL, creator, trackCount, tracks, isEditable
}
```

## Library Specification

### Library Categories
- Liked tracks, Saved albums, Saved artists, Saved playlists
- Recently played, Play history, Custom playlists

### Library Operations
- Add/remove songs, Save albums/artists/playlists
- Create/rename/delete playlists
- Add/remove/reorder tracks
- View recently played

### Local Library Behaviour
- Actions immediate: interface updates, persisted locally, visual confirmation, survives restart
- Library state does NOT depend on active YouTube Music login

### Playlist Model
```swift
Playlist {
    ID, Name, Description, Artwork, CreatedAt, UpdatedAt, TrackIDs, SortOrder
}
```

### Persistence
- SwiftData for structured entities
- UserDefaults for small preferences
- File storage for larger assets
- Memory cache for transient results
- Repository interfaces for abstraction

## Playback Specification

### Player States
- idle, loading, ready, playing, buffering, failed, ended

### Required Controls
- Play, Pause, Previous, Next, Seek, Volume, Shuffle, Repeat off/one/all, Queue access, Track information, Album artwork

### Queue
- Current track, Upcoming tracks, Add track, Add to end, Play next, Remove track, Reorder, Clear, Shuffle queue, Repeat mode, Queue persistence

### Mini-player
- Visible when track selected and player state active
- Displays: artwork, title, artist, playback state, progress, play/pause, expand interaction
- Remains available while navigating

### Full Player
- Large album artwork, track title, artist, artwork-driven ambient background, glass controls, seek bar, play/pause, next, previous, queue, shuffle, repeat, optional lyrics, context menu

### Playback Provider Interface
```swift
protocol PlaybackProvider {
    func prepare(track: Track)
    func play()
    func pause()
    func seek(to position: TimeInterval)
    func stop()
}
```

### Playback MVP
- Player UI works, track selection works, queue management works, playback state observable
- Demo/preview modes clearly identified
- Unsupported tracks produce honest state (don't fake success)

## Album, Artist, Playlist Detail Screens

### Album Screen (16.1)
- Display: artwork, title, artist, release date, album type, track list, track durations
- Interactions: Play album, Shuffle album, Save album, Contextual menu
- Track selection: Set as active player item, add album context to queue, open/update mini-player, preserve information

### Artist Screen (16.2)
- Display: artwork, name, description, top tracks, albums, singles, related artists
- Actions: Play, Shuffle, Follow/save artist
- Lazy retrieval where possible

### Playlist Screen (16.3)
- Display: artwork, name, creator, description, track list, play, shuffle, save, queue actions

## Artwork and Image System

### Artwork Importance
- Album covers are NOT disposable thumbnails

### Image Loading
- Asynchronous loading, caching, avoid repeated downloads, support different sizes, handle invalid URLs/unavailable artwork, display placeholders, avoid blocking scrolling, prevent layout jumping

### Image Cache
- Memory cache, optional disk cache, cache invalidation, maximum cache size, reusable image loading

### Artwork Presentation
- Home carousels, search results, album screens, artist screens, playlists, mini-player, full player, library

## UI Interaction & Motion

### Interaction Philosophy
- Physical, responsive, intentional
- Avoid excessive animation for animation's sake

### Required Interactions
- Tap album: Open album detail
- Tap track: Select/play or enqueue
- Tap artist: Open artist
- Tap mini-player: Expand player
- Swipe down player: Collapse player
- Tap play/pause: Change playback state
- Swipe carousel: Scroll music content
- Long press track: Open contextual actions
- Search typing: Debounced search
- Pull to refresh: Refresh relevant content
- Save: Immediate library update

### Animation Requirements
- Spring-based transitions
- Smooth player expansion
- Fluid navigation
- Artwork transitions where practical
- Mini-player expansion animation
- Subtle button feedback
- Queue transitions
- Skeleton-to-content transitions
- Contextual glass animation

### Accessibility
- Reduce Motion, VoiceOver, Dynamic Type, accessibility labels, high contrast, safe areas, touch target sizes, keyboard navigation
- Animations have reduced/simplified alternatives

## Settings & Preferences (24.1-24.2)
- Appearance: System, Dark (Light may be added later)
- Developer/debug settings available in development builds only

## State Management (23.1-23.3)
### Global State
- Current player, current queue, current playback state, current tab, mini-player visibility, current library, search history, user preferences

### State Ownership
- One authoritative owner per state type
- Search query: Search ViewModel
- Search results: Search ViewModel / Catalog repository
- Library tracks: Library repository
- Queue: Player Store
- Current track: Player Store
- Playback status: Playback service
- Settings: Preferences service
- Home sections: Home ViewModel
- API status: API client / health service

### State Persistence
- Persist: Saved tracks, saved albums, saved artists, custom playlists, playback queue, search history, user preferences
- Do NOT persist: Transient states like loading indicators

## Backend Deployment & Configuration (26.1-26.5)
### Environment Configuration
- Environment variables: APP_ENV, API_HOST, API_PORT, LOG_LEVEL, CACHE_TTL_SEARCH, CACHE_TTL_TRACK, PROVIDER_TIMEOUT, PROVIDER_MAX_CONCURRENCY

### Environments
- Local development, Testing, Staging, Production
- Environment-specific config not hardcoded in Swift app

### iOS Configuration
- Development API base URL, Staging API base URL, Production API base URL
- Endpoint controlled through configuration

### Deployment Options
- Docker, managed container service, Python hosting platform, VPS
- Reproducible deployment

### Observability
- Health checks, structured logs, error logs
- Provider request latency, cache hit ratio, request counts
- Failure counts, timeout counts
- Sensitive information never logged

## Security & Privacy (28.1-28.4)
### General
- Collect as little user information as possible

### Data Security
- No API credentials in iOS bundle
- No credentials in repository
- No secret values in debug logs
- Backend secrets through environment variables/secure management
- Request validation on all endpoints
- Controlled error responses
- Rate limiting
- HTTPS in deployed environments
- No unsafe dynamic execution
- No arbitrary backend URL manipulation

### User Privacy
- Initial release doesn't require account
- Local library remains local unless explicit sync feature
- Don't send: personal listening history, user-created playlists, library contents, search history to external services unless explicitly required and user understands

### Provider Boundaries
- ytmusicapi shall not: extract protected audio streams, bypass content restrictions, pretend metadata access grants playback rights, store Google credentials in client, circumvent authentication protections, expose provider cookies to frontend
- Metadata service is for catalog discovery and information

## Performance Requirements (31.1-31.2)
### Metrics
- App launch to first usable frame: Under 2 seconds
- Local tab switching: Under 250 ms perceived response
- Search UI response: Immediate
- Search request debounce: 300 to 450 ms
- Cached catalog response: Under 500 ms target
- Uncached catalog response: Under 5 seconds target under healthy conditions
- Artwork loading: Non-blocking
- Scrolling: Consistently smooth, ideally 60 FPS or higher
- Player controls: Immediate UI response
- App crash rate: Below 1% sessions
- Main UI thread: No network or decoding work blocking it

### Slow Network Behaviour
- UI must remain responsive
- Search input must remain usable
- Loading indicators appear
- Previously loaded content remains visible
- Requests cancellable
- Outdated query results don't overwrite newer ones
- Timeout states understandable

### Low-Memory Behaviour
- Avoid retaining excessive artwork
- Release temporary image resources
- Avoid huge search result collections
- Paginate large catalog results
- Avoid unnecessary duplicate models
- Maintain bounded cache

## Testing Requirements (27.1-27.5)

### Backend Unit Tests
- Search query validation, category mapping, result normalization
- Missing metadata, malformed provider responses
- Cache behaviour, error mapping, provider timeout, rate limiting

### Backend Integration Tests
- FastAPI routes, mocked provider calls
- Search, album, artist, playlist requests
- Health endpoint, provider failure, cache fallback
- Should NOT depend on live YouTube Music requests in CI

### iOS Unit Tests
- Track model, search state, search debouncing
- Library operations, playlist ordering
- Queue operations, playback state transitions
- API response decoding, error handling

### UI Tests
- Initial launch, tab navigation, search
- Search result selection, saving tracks
- Library rendering, mini-player opening
- Full-player closing, empty states, error states
- Settings navigation

### Manual Test Matrix
- Backend offline: App remains usable, error displayed
- Empty search: Validation or idle state
- No results: Empty result message
- Provider timeout: Controlled error
- Missing artwork: Placeholder
- Missing artist: Track still displays
- Duplicate search results: No accidental identity merging
- Save track: Persists after relaunch
- Remove track: Removed from local library
- Queue track: Queue updates
- Change tabs: Player state persists
- Expand mini-player: Full player appears
- Playback unavailable: Honest unavailable state
- Network disconnect: Cached content remains usable
- Search rapidly: Only latest query results appear

## Functional Requirements (FR-001 to FR-050)

### P0: Required for MVP
- FR-001: Application shall launch successfully
- FR-002: Application shall provide native navigation
- FR-003: Application shall display Home
- FR-004: Application shall search catalog
- FR-005: Search shall support songs
- FR-006: Search shall support artists
- FR-007: Search shall support albums
- FR-008: Search shall support playlists
- FR-009: Search results shall display artwork where available
- FR-010: Search results shall display normalized metadata
- FR-011: Application shall support opening album detail
- FR-012: Application shall support opening artist detail
- FR-013: Application shall support opening playlist detail
- FR-014: Application shall provide a local Library
- FR-015: User shall save music locally
- FR-016: User shall remove music from local Library
- FR-017: Local Library shall persist
- FR-018: Application shall provide a mini-player
- FR-019: Mini-player shall expand
- FR-020: Application shall provide queue functionality
- FR-021: App shall display backend errors gracefully
- FR-022: App shall support artwork caching
- FR-023: App shall support loading and empty states
- FR-024: App shall implement the defined design language
- FR-025: App shall respect basic accessibility settings

### P1: Polished Release
- FR-026: Search history
- FR-027: Home recommendations
- FR-028: Recently played
- FR-029: Custom playlists
- FR-030: Shuffle
- FR-031: Repeat modes
- FR-032: Artist related content
- FR-033: Album track ordering
- FR-034: Settings
- FR-035: Dynamic artwork atmosphere
- FR-036: Lyrics when available
- FR-037: Cache management
- FR-038: Request cancellation
- FR-039: Context menus
- FR-040: Playlist editing

### P2: Future Improvements
- FR-041: Account synchronisation
- FR-042: Additional music providers
- FR-043: Local media support
- FR-044: Advanced recommendations
- FR-045: Offline catalog cache
- FR-046: Listening statistics
- FR-047: Cross-device sync
- FR-048: Smart playlists
- FR-049: Enhanced accessibility
- FR-050: Widget support

## Project Structure (28)

### Target Architecture
```
AvocadoToast/
├── README.md
├── .gitignore
├── ios/
│   └── AvocadoToast/
│       ├── App/
│       │   ├── AvocadoToastApp.swift
│       │   ├── AppConfig.swift
│       │   └── AppCoordinator.swift
│       ├── Core/
│       │   ├── Networking/
│       │   │   ├── APIClient.swift
│       │   │   ├── APIEndpoint.swift
│       │   │   └── APIError.swift
│       │   ├── Theme/
│       │   │   ├── AppTheme.swift
│       │   │   ├── ColorTokens.swift
│       │   │   ├── GlassStyles.swift
│       │   │   └── Typography.swift
│       │   ├── Persistence/
│       │   │   ├── LibraryRepository.swift
│       │   │   └── PersistenceController.swift
│       │   └── Utilities/
│       ├── Models/
│       │   ├── Track.swift
│       │   ├── Album.swift
│       │   ├── Artist.swift
│       │   ├── Playlist.swift
│       │   └── SearchResult.swift
│       ├── Services/
│       │   ├── CatalogService.swift
│       │   ├── LibraryService.swift
│       │   ├── ArtworkService.swift
│       │   ├── PlayerService.swift
│       │   └── SearchService.swift
│       ├── Features/
│       │   ├── Home/
│       │   │   ├── HomeView.swift
│       │   │   ├── HomeViewModel.swift
│       │   │   └── Components/
│       │   ├── Search/
│       │   │   ├── SearchView.swift
│       │   │   ├── SearchViewModel.swift
│       │   │   └── Components/
│       │   ├── Library/
│       │   │   ├── LibraryView.swift
│       │   │   ├── LibraryViewModel.swift
│       │   │   └── Components/
│       ├── Player/
│       │   ├── MiniPlayerView.swift
│       │   ├── NowPlayingView.swift
│       │   ├── QueueView.swift
│       │   └── PlayerViewModel.swift
│       │   └── Settings/
│       └── Resources/
├── backend/
│   ├── pyproject.toml
│   ├── README.md
│   │
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── router.py
│   │   │       └── endpoints/
│   │   │
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   │   ├── catalog_service.py
│   │   │   ├── search_service.py
│   │   │   └── cache_service.py
│   │   │
│   │   ├── providers/
│   │   │   ├── base.py
│   │   │   └── ytmusic/
│   │   │       ├── client.py
│   │   │       ├── adapter.py
│       │       └── normalizer.py
│   │   │
│   │   ├── middleware/
│   │   └── utils/
│   └── tests/
├── docs/
│   ├── SRS.md
│   ├── ARCHITECTURE.md
│   ├── API.md
│   ├── DESIGN_SYSTEM.md
│   └── DEVELOPMENT.md
└── assets/
```

## Development Phases

### Phase 0: Project Foundation
- Inspect Xcode project configuration
- Establish project build settings
- Establish minimum iOS version
- Establish backend environment
- Create stable API models
- Confirm repository structure
- Define visual design tokens
- **Exit**: Xcode project opens, app launches, backend health checks work

### Phase 1: UI Foundation
- Root navigation
- Glass material system
- Typography
- Background system
- Artwork component
- Track row
- Album card
- Artist card
- Playlist card
- Mini-player
- Navigation transitions
- **Exit**: All core screens exist and are navigable with mock data

### Phase 2: Catalog Backend
- FastAPI architecture
- Provider interface
- ytmusicapi adapter
- Search
- Normalization
- Error handling
- Caching
- Health endpoint
- Unit tests
- **Exit**: Catalog search returns normalized, validated data through API

### Phase 3: Catalog Frontend
- Search screen integration
- Home integration
- Album details
- Artist details
- Playlist details
- Artwork loading
- Loading states
- Empty states
- Error states
- **Exit**: Application can discover and browse real music catalog data

### Phase 4: Library
- Persistence
- Save tracks, albums, artists, playlists
- Custom playlists
- Library filtering
- Recent listening
- **Exit**: User can create and maintain a persistent personal library

### Phase 5: Player
- Player state machine
- Queue
- Mini-player
- Full player
- Previous/next, Seek
- Shuffle, Repeat
- Provider integration boundary
- Playback error states
- **Exit**: Player UI and state management work correctly, with actual playback available wherever a supported provider is integrated

### Phase 6: Polish
- Motion
- Artwork transitions
- Glass refinements
- Accessibility
- Performance
- Cache
- Backend resilience
- Tests
- Error recovery
- **Exit**: Stable enough for proper device test

### Phase 7: Build and Release Preparation
- Compile in Xcode
- Resolve warnings
- Test simulator
- Test physical iPhone
- Verify API connectivity
- Verify persistence
- Verify offline and failure cases
- Verify all screens
- Prepare release configuration
- **Exit**: Reproducible, verified iOS build produced

## Acceptance Criteria for Complete Build (32.1-32.5)

### Application Acceptance
- App launches on a supported iOS device
- No startup crash
- Navigation functions
- All primary screens exist
- All primary screens have their intended UI
- Liquid Glass styling is consistent
- The app has its own branding
- Safe areas are respected
- Layout does not break on supported screen sizes

### Catalog Acceptance
- Backend health endpoint works
- Search works
- Search filters work
- Results are normalized
- Artwork loads
- Album details work
- Artist details work
- Playlist details work
- Provider failures do not crash the client
- Cached results behave appropriately

### Library Acceptance
- Track can be saved
- Track can be removed
- Album can be saved
- Artist can be saved
- Playlist can be saved
- Custom playlist can be created
- Custom playlist can be modified
- Library survives application restart

### Player Acceptance
- Track can be selected
- Queue can be modified
- Mini-player updates
- Mini-player expands
- Mini-player collapses
- Playback state accurately represented
- Play and pause connected to an actual playback engine
- Unsupported playback is handled honestly
- The player does not lose state on tab switching

### Quality Acceptance
- No obvious UI clipping
- No unresponsive controls
- No duplicate network requests from uncontrolled typing
- No hardcoded test data presented as live data
- No exposed credentials
- No broken navigation
- No uncontrolled memory usage
- No critical console errors
- Backend tests pass
- Core iOS tests pass
- Build is verified in Xcode

## Risks & Mitigation (35)
| Risk | Impact | Mitigation |
|------|--------|------------|
| ytmusicapi changes | Catalog integration breaks | Isolate adapter, pin dependency |
| Provider rate limits | Search unreliable | Caching, concurrency limits |
| Provider unavailable | Home/search fail | Graceful failure, cached data |
| Metadata inconsistency | UI unpredictable | Normalize every response |
| Playback source unavailable | Player can't play catalog tracks | Separate metadata from playback |
| Xcode project incompatibility | Build fails | Inspect project before restructuring |
| Liquid Glass overuse | UI unreadable | Establish surface hierarchy |
| Excessive artwork loading | Memory/performance issues | Image caching and limits |
| Large project scope | Development stalls | Strict MVP prioritization |
| Backend deployment failure | iOS can't access catalog | Health endpoint, environment checks |
| Unstable identifiers | Duplicate library entries | Preserve provider IDs and internal IDs |
| Outdated search responses | Wrong results display | Cancellation and query identity checks |

## Definition of Success (36)
Avocado Toast is successful first release when it feels like a cohesive music application, not collection of screens. Must have:
- Recognisable identity
- Genuinely beautiful interface
- Responsive navigation
- Functional music discovery
- Real catalog metadata
- Persistent local library
- Coherent player experience
- Maintainable backend
- Stable provider abstraction
- Properly handled errors
- Verified build

**Most important technical decision**: Separation between the catalog, the library, and the playback engine. This prevents corner-cutting when YouTube Music metadata works but playback requires a different provider or implementation.

**ytmusicapi integration**: Initially powers catalog discovery, search, metadata, albums, artists, playlists, related music. Must be isolated behind provider adapter (unofficial API).

## Final Product Vision
- Lavish design, boringly reliable engineering
- "Music should feel like somewhere you go, not something you scroll through"
- Obsessive attention to interface design, genuinely useful catalog, personal library, evolving player architecture

---