# AvocadoToast Rebuild Notes

Branch: `fuhahh-try`

## Direction
Native iPhone app. No required desktop companion or production backend. YouTube Music remains the catalog/discovery source, while playback integration must be reviewed separately for technical reliability, licensing, and platform terms. Do not claim metadata access equals playback permission.

## Current rebuild work
- Reworked root tabs and shared mini-player presentation.
- Rebuilt Listen/Home around search, featured artwork, catalog cards, mood shortcuts, refresh, and Settings navigation.
- Added home loading lifecycle state.
- Rebuilt Search and removed unsupported fake category filters.
- Rebuilt Settings, removed PC/backend URL controls, and added confirmed SwiftData library reset.
- Connected mini-player and Now Playing to the catalog player state.
- Added playback progress updates.
- Established warm espresso, avocado olive, butter, toast, and ivory colors, with dark mode as the default.
- Made theme selection persistent and wired it to the app's preferred color scheme.
- Repaired the Library screen and added more human empty states and playlist creation.
- Connected catalog track saves to SwiftData instead of only keeping them in memory.
- Unified the app and service persistence contexts through PersistenceController.
- Split audio playback paths: AVPlayer for remote URLs and AVAudioEngine for local files, so remote URLs are no longer passed to AVAudioFile.
- Added GitHub Actions iOS Simulator compilation so source changes are checked by a real Xcode build.

## Build verification
A first CI build was triggered and caught a SwiftUI conditional-view type error in Search. That error has been fixed and a follow-up build is running. Do not mark this pass as build-clean until the latest CI run succeeds.

## Known work still required
- Finish CI compile and address any remaining compiler errors.
- Validate playback on a physical device. The existing source resolver is unofficial and fragile. Metadata access is not a guarantee of permitted or reliable playback.
- Consolidate catalog/player state, then implement queue behavior, background audio, lock-screen controls, interruption handling, and persistent queue state.
- Audit detail screens, Library interactions, playlist behavior, settings and context menus. Remove fake controls or connect them to real actions.
- Add tests and perform accessibility, responsiveness, and iPhone device checks.
- Review licensing of third-party code before adoption.

## Honest UI rule
Never show a control for a capability that is not wired to a real action. If a capability is unavailable or not yet implemented, remove the control or show a clear unavailable state.
