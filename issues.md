# Avocado Toast — Known Issues

## Summary

The app builds and installs on iOS devices, but several core features are broken when connecting to YouTube Music through the unofficial InnerTube API (SwiftyTube).

---

## Issues

### 1. Build failure (FIXED)
**Symptom:** The app would not compile at all.
**Root cause:** `SettingsView.swift` accessed `AccountInfo.name` and `AccountInfo.email` from SwiftyTube without importing the `SwiftyTube` module.
**Fix:** Added `import SwiftyTube` to `SettingsView.swift`.
**Status:** Fixed in commit `0d22a11`.

### 2. Guest-mode search returns empty results
**Symptom:** Typing a search query in guest mode returns "No matches this time" instead of results.
**Root cause:** Guest-mode search requests lack an `X-Goog-Visitor-Id` header. YouTube Music's InnerTube search endpoint requires a visitor token, which is normally obtained by first browsing the home page (`ensureVisitorData()`).
**Fix:** Added `ensureVisitorData()` call before search, plus multi-client fallback (WEB_REMIX, WEB, iOS clients).
**Status:** Partially fixed — song search now works; artist/album/playlist search still returns empty.

### 3. Typed search (artists, albums, playlists) returns nothing
**Symptom:** Switching search category to Artists, Albums, or Playlists shows empty results.
**Root cause:** Each typed search only tried one YouTube client (`config.defaultClient` = WEB_REMIX). Some clients reject filtered search requests.
**Fix:** Added multi-client loop across WEB_REMIX, WEB, and iOS clients for all typed search methods.
**Status:** Fixed in code, still needs device testing.

### 4. Playback does not work
**Symptom:** Tapping a song does not play audio; no error shown or generic failure.
**Root cause:** YouTube Music protects audio streams behind PoTokens, signature timestamps, cipher decoding, and client-specific attestation. `StreamFallback.resolveFirstValid` tries multiple clients internally but all fail on-device without proper PoToken generation.
**Fix:** Stream resolution already uses SwiftyTube's built-in multi-client fallback chain. Error messaging improved to show "Stream resolution failed" instead of silent failure.
**Status:** Still broken — requires PoToken provider and/or cipher implementation that SwiftyTube's free tier does not include out of the box.

### 5. Home screen does not load
**Symptom:** The Home/Listen tab shows empty or loading indefinitely.
**Root cause:** `fetchMusicHome()` only attempted one client (WEB_REMIX). YouTube Music's home browse endpoint may reject or return different layouts depending on client and auth state.
**Fix:** Added multi-client fallback for home feed browsing.
**Status:** Fixed in code, still needs device testing.

### 6. Thumbnails appear stretched
**Symptom:** Square artwork looks squashed/distorted in UI elements.
**Root cause:** `ArtworkService.resize()` used `draw(in: CGRect(origin: .zero, size: size))`, which stretches non-square source images to fill the target rectangle without preserving aspect ratio.
**Fix:** Changed to aspect-fill center-crop: scale to cover the target size, then center-crop excess.
**Status:** Fixed in `ArtworkService.swift`.

### 7. Signed-in playlists / account library
**Symptom:** After signing in with Google, personal playlists and library do not appear.
**Root cause:** Account library browsing uses the same `browse()` endpoint that fails in guest mode. Even with valid cookies and SAPISID, the response format may not match the parser expectations.
**Status:** Not yet fixed.

---

## Files Changed

| File | Change |
|------|--------|
| `AvocadoToast/Features/Settings/SettingsView.swift` | Added `import SwiftyTube` |
| `AvocadoToast/AvocadoToastCore/Services/YouTubeKitService.swift` | Multi-client fallback for search, home, playlists; visitor data before search; better error messages |
| `AvocadoToast/Core/Services/ArtworkService.swift` | Aspect-fill center-crop resize instead of stretch |

---

## What Still Needs Work

1. **Artist/Album/Playlist search** — returns empty even with multi-client fallback; parsers may not match current YouTube Music response format
2. **Audio playback** — stream resolution fails on all clients; requires PoToken generation and cipher handling
3. **Home feed** — multi-client fallback added but still untested on device
4. **Signed-in account library** — personal playlists/saved music not loading after Google sign-in
5. **Physical device testing** — all fixes above need verification on an actual iPhone

---

## Notes

- YouTube Music / InnerTube is an unofficial integration. Google can change response formats or add protections at any time, breaking third-party clients.
- Simulator compilation does not prove remote audio works on-device.
- No unit-test target currently exists.