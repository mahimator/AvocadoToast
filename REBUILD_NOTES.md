# AvocadoToast Rebuild Notes

Branch: `fuhahh-try`

## Direction
Native iPhone app. No required desktop companion or production backend. YouTube Music remains the catalog/discovery source, while playback integration must be reviewed separately for technical reliability, licensing, and platform terms. Do not claim metadata access equals playback permission.

## Work completed in this rebuild pass
- Reworked the root tabs and shared mini-player presentation.
- Rebuilt Listen/Home around a search entry, featured artwork, catalog cards, mood shortcuts, refresh, and Settings navigation.
- Added home loading lifecycle state to avoid repeatedly loading the feed on every appearance.
- Rebuilt Search presentation, connected the Home search entry and mood shortcuts to the shared query, and removed category chips that were not backed by category-specific query behavior.
- Rebuilt Settings, removed the PC/backend URL controls, and made the library reset action destructive-confirmed and functional for SwiftData entities.
- Connected mini-player and Now Playing screens to the catalog's AudioPlayerService instead of the disconnected legacy PlayerService.
- Added elapsed-time updates to the audio engine for the Now Playing slider.

## Known work still required
- Compile the full app in Xcode and fix compiler errors. This environment cannot run Xcode/iOS SDK builds.
- Validate playback on a physical device. Existing source resolution is unofficial and must not be treated as a guaranteed or permitted playback mechanism.
- Replace the split catalog/player architecture with a clearly defined single playback state owner, queue persistence, and robust interruption/background/lock-screen behavior.
- Review all feature buttons and actions in detail screens, Library, Settings, and context menus for real implementation.
- Add automated tests and an iPhone accessibility/performance pass.
- Review package licensing before adopting third-party code.

## Honest UI rule
Never show a control for a capability that is not wired to a real action. If the underlying capability is unavailable or not yet implemented, remove the control or show a clear unavailable state.
