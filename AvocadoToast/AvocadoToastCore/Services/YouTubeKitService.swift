//
//  YouTubeKitService.swift
//  AvocadoToast
//
//  Direct YouTube Music integration via SwiftyTube.
//  No backend, no PC required — communicates directly with YouTube's InnerTube API.
//

import Foundation
import Combine
import AVFoundation
import SwiftyTube

@MainActor
final class YouTubeKitService: ObservableObject {
    static let shared = YouTubeKitService()

    private let client: InnerTubeClient
    private let config: SwiftyTubeConfig

    @Published var isSearching = false
    @Published var searchError: String?

    private init() {
        self.config = SwiftyTubeConfig.music
        self.client = InnerTubeClient(config: config, auth: .guest)
    }

    func loadSavedSession() async {
        await client.loadState(from: YouTubeAccountSession.shared)
    }

    func fetchAccountInfo() async throws -> AccountInfo {
        try await client.accountInfo(client: config.defaultClient)
    }

    func useGuestSession() async {
        await client.updateAuth(.guest)
    }

    // MARK: - Home discovery

    /// Returns the real YouTube Music Home response as a discovery source.
    /// Presentation and shelf selection stay owned by Avocado Toast.
    func fetchMusicHome() async throws -> [String: Any] {
        try? await client.ensureVisitorData()
        let clients: [YouTubeClient] = [config.defaultClient, .web, .iOS]
        var lastError: Error?
        for client in clients {
            do {
                let json = try await self.client.browse(browseId: "FEmusic_home", client: client)
                DiagnosticLogger.shared.logHome(success: true, trackCount: 0, error: nil)
                return json
            } catch {
                lastError = error
                continue
            }
        }
        DiagnosticLogger.shared.logHome(success: false, trackCount: 0, error: lastError?.localizedDescription)
        throw lastError ?? InnerTubeError.invalidResponse
    }

    // MARK: - Personal YouTube Music library

    func fetchLibrarySnapshot() async throws -> YouTubeLibrarySnapshot {
        try? await client.ensureVisitorData()

        let requests: [(String, String)] = [
            ("songs", "FEmusic_liked_videos"),
            ("playlists", "FEmusic_library_playlists"),
            ("albums", "FEmusic_library_albums"),
            ("artists", "FEmusic_library_artists")
        ]
        var responses: [String: [String: Any]] = [:]
        var lastError: Error?

        for (kind, browseID) in requests {
            let clients: [YouTubeClient] = [config.defaultClient, .web, .iOS]
            var response: [String: Any]?
            for candidate in clients {
                do {
                    response = try await client.browse(browseId: browseID, client: candidate)
                    break
                } catch {
                    lastError = error
                    DiagnosticLogger.shared.write("LIBRARY \(kind) browse failed client=\(candidate.clientName): \(error.localizedDescription)")
                }
            }
            if let response { responses[kind] = response }
        }

        guard !responses.isEmpty else {
            throw lastError ?? InnerTubeError.invalidResponse
        }

        let songs = LibraryBrowseParser.parseSongs(from: responses["songs"] ?? [:])
        let tracks = songs.map { song in
            YouTubeTrack(
                videoId: song.videoId,
                title: song.title,
                artist: song.artists.isEmpty ? "Unknown Artist" : song.artists.joined(separator: ", "),
                duration: Double(song.duration),
                thumbnailURL: song.thumbnailUrl
            )
        }

        let playlists = LibraryBrowseParser.parsePlaylists(from: responses["playlists"] ?? [:]).map { item in
            YouTubePlaylist(
                playlistId: item.browseId,
                title: item.title,
                thumbnailURL: item.thumbnailUrl,
                videoCountText: item.songCount.map { "\($0) songs" }
            )
        }

        let albums = LibraryBrowseParser.parseAlbums(from: responses["albums"] ?? [:])
        let artists = LibraryBrowseParser.parseArtists(from: responses["artists"] ?? [:]).map { item in
            YouTubeChannel(
                channelId: item.channelId ?? item.browseId,
                title: item.name,
                thumbnailURL: item.thumbnailUrl
            )
        }

        DiagnosticLogger.shared.write("LIBRARY snapshot songs=\(tracks.count) playlists=\(playlists.count) albums=\(albums.count) artists=\(artists.count)")
        return YouTubeLibrarySnapshot(tracks: tracks, playlists: playlists, albums: albums, artists: artists)
    }

    // MARK: - Search

    func search(term: String, limit: Int = 25) async -> [YouTubeTrack] {
        isSearching = true
        searchError = nil
        defer { isSearching = false }

        // Ensure visitor data is set so guest-mode search includes
        // an X-Goog-Visitor-Id header.
        try? await client.ensureVisitorData()

        // Try multiple YouTube clients — Music search may be restricted on some
        // clients but work on others. Guest mode especially needs a fallback.
        let clients: [YouTubeClient] = [config.defaultClient, .web, .iOS]

        var lastError: Error?

        for client in clients {
            do {
                let json = try await self.client.search(query: term, client: client)

                // Music search returns musicResponsiveListItemRenderer rows, not
                // ordinary videoRenderer rows. Parse Music rows first, then use the
                // general parser as a fallback for mixed/legacy results.
                let songs = LibraryBrowseParser.parseSongs(from: json)
                if !songs.isEmpty {
                    var seen = Set<String>()
                    let result = songs.filter { seen.insert($0.videoId).inserted }
                        .prefix(limit).map { song in
                            YouTubeTrack(
                                videoId: song.videoId,
                                title: song.title,
                                artist: song.artists.isEmpty ? "Unknown Artist" : song.artists.joined(separator: ", "),
                                duration: Double(song.duration),
                                thumbnailURL: song.thumbnailUrl
                            )
                        }
                    DiagnosticLogger.shared.logSearch(term: term, type: "songs", client: client.clientName, resultCount: result.count, error: nil)
                    return Array(result)
                }

                let videos = YouTubeFeedParser.searchResults(in: json).videos
                if !videos.isEmpty {
                    let result = videos.prefix(limit).map { video in
                        YouTubeTrack(
                            videoId: video.videoId,
                            title: video.title,
                            artist: video.channelTitle ?? "Unknown Artist",
                            duration: video.durationSeconds.map { Double($0) } ?? 0,
                            thumbnailURL: video.thumbnailURL
                        )
                    }
                    DiagnosticLogger.shared.logSearch(term: term, type: "videos", client: client.clientName, resultCount: result.count, error: nil)
                    return result
                }
            } catch {
                lastError = error
                DiagnosticLogger.shared.logSearch(term: term, type: "songs", client: client.clientName, resultCount: 0, error: error.localizedDescription)
                continue
            }
        }

        if let lastError {
            searchError = "Search failed: \(lastError.localizedDescription)"
        } else {
            searchError = "No results found. \(YouTubeAccountSession.shared.isSignedIn ? "" : "Sign in to YouTube Music to search.")"
        }
        DiagnosticLogger.shared.logSearch(term: term, type: "songs", client: "all_failed", resultCount: 0, error: searchError)
        return []
    }

    // MARK: - Stream resolution

    /// Resolves a playable audio stream URL for a YouTube video ID.
    func resolveStream(videoId: String) async -> String? {
        searchError = nil

        func usableURL(_ value: String?) -> String? {
            guard let value, let url = URL(string: value),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http",
                  url.host != nil else { return nil }
            return value
        }

        func isAACCompatible(_ mimeType: String?) -> Bool {
            guard let mime = mimeType?.lowercased() else { return false }
            return mime.contains("mp4a") || mime.contains("aac") || mime.contains("mp4")
        }

        // Strategy 1: Direct iOS client player response — gives iPhone-compatible
        // URLs with AAC/MP4A formats that AVPlayer can play natively.
        do {
            let response = try await client.player(videoId: videoId, client: .iOS)
            if let streamingData = response["streamingData"] as? [String: Any] {
                let formats = (streamingData["formats"] as? [[String: Any]] ?? [])
                    + (streamingData["adaptiveFormats"] as? [[String: Any]] ?? [])
                // Try AAC-compatible formats first, then any audio format
                let ordered = formats.sorted { lhs, rhs in
                    let lhsAAC = isAACCompatible(lhs["mimeType"] as? String)
                    let rhsAAC = isAACCompatible(rhs["mimeType"] as? String)
                    if lhsAAC && !rhsAAC { return true }
                    if !lhsAAC && rhsAAC { return false }
                    return false
                }
                for format in ordered {
                    if let url = usableURL(format["url"] as? String) {
                        DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 1, client: "ios_player_aac", success: true, error: nil)
                        return url
                    }
                }
            }
            DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 1, client: "ios_player_aac", success: false, error: "No directly usable audio URL in iOS player response")
        } catch {
            DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 1, client: "ios_player_aac", success: false, error: error.localizedDescription)
        }

        // Strategy 2: SwiftyTube's complete live provider bundle.
        let request = StreamResolveRequest.playback(
            videoId: videoId,
            options: StreamResolveOptions(
                forDownload: false,
                audioQuality: .high,
                videoQuality: .auto
            )
        )
        do {
            let result = try await StreamFallback.resolveFirstValid(
                request,
                using: client,
                providers: .live
            )
            if let url = usableURL(result.streamUrl) {
                DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 2, client: "fallback_live", success: true, error: nil)
                return url
            }
            DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 2, client: "fallback_live", success: false, error: "Provider returned an invalid stream URL")
        } catch {
            DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 2, client: "fallback_live", success: false, error: error.localizedDescription)
        }

        // Strategy 3: Standard YouTube client chain as the final fallback.
        do {
            var fallbackRequest = request
            fallbackRequest.chain = ClientFallbackChain.youtube
            let result = try await StreamFallback.resolveFirstValid(
                fallbackRequest,
                using: client,
                providers: .live
            )
            if let url = usableURL(result.streamUrl) {
                DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 3, client: "youtube_fallback", success: true, error: nil)
                return url
            }
            searchError = "YouTube returned a stream response without a usable audio URL."
            DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 3, client: "youtube_fallback", success: false, error: searchError)
        } catch {
            searchError = "Stream resolution failed: \(error.localizedDescription)"
            DiagnosticLogger.shared.logStream(videoId: videoId, attempt: 3, client: "youtube_fallback", success: false, error: error.localizedDescription)
        }

        return nil
    }

    // MARK: - Typed catalog search

    func searchArtists(term: String, limit: Int = 20) async -> [YouTubeChannel] {
        searchError = nil
        try? await client.ensureVisitorData()
        let clients: [YouTubeClient] = [config.defaultClient, .web, .iOS]
        var lastError: Error?
        for client in clients {
            do {
                let json = try await self.client.search(
                    query: term,
                    params: YouTubeSearchFilter.channel.rawValue,
                    client: client
                )
                // First try the dedicated library-style parser
                let artists = LibraryBrowseParser.parseArtists(from: json)
                if !artists.isEmpty {
                    let result = artists.prefix(limit).map { artist in
                        YouTubeChannel(
                            channelId: artist.channelId ?? artist.browseId,
                            title: artist.name,
                            thumbnailURL: artist.thumbnailUrl
                        )
                    }
                    DiagnosticLogger.shared.logSearch(term: term, type: "artists", client: client.clientName, resultCount: result.count, error: nil)
                    return Array(result)
                }
                // Fallback: general search results — search responses use a
                // different JSON structure than browse pages, so LibraryBrowseParser
                // often returns empty. YouTubeFeedParser is more tolerant.
                let results = YouTubeFeedParser.searchResults(in: json)
                if !results.channels.isEmpty {
                    let result = results.channels.prefix(limit).map { channel in
                        YouTubeChannel(
                            channelId: channel.channelId ?? channel.handle ?? channel.title,
                            title: channel.title,
                            thumbnailURL: channel.thumbnailURL
                        )
                    }
                    DiagnosticLogger.shared.logSearch(term: term, type: "artists", client: client.clientName, resultCount: result.count, error: nil)
                    return Array(result)
                }
            } catch {
                lastError = error
                DiagnosticLogger.shared.logSearch(term: term, type: "artists", client: client.clientName, resultCount: 0, error: error.localizedDescription)
                continue
            }
        }
        searchError = lastError.map { "Artist search failed: \($0.localizedDescription)" } ?? "Artist search failed"
        DiagnosticLogger.shared.logSearch(term: term, type: "artists", client: "all_failed", resultCount: 0, error: searchError)
        return []
    }

    func searchPlaylists(term: String, limit: Int = 20) async -> [YouTubePlaylist] {
        searchError = nil
        try? await client.ensureVisitorData()
        let clients: [YouTubeClient] = [config.defaultClient, .web, .iOS]
        var lastError: Error?
        for client in clients {
            do {
                let json = try await self.client.search(
                    query: term,
                    params: YouTubeSearchFilter.playlist.rawValue,
                    client: client
                )
                let playlists = LibraryBrowseParser.parsePlaylists(from: json)
                if !playlists.isEmpty {
                    let result = playlists.prefix(limit).map { playlist in
                        YouTubePlaylist(
                            playlistId: playlist.browseId,
                            title: playlist.title,
                            thumbnailURL: playlist.thumbnailUrl,
                            videoCountText: playlist.songCount.map { "\($0) songs" }
                        )
                    }
                    DiagnosticLogger.shared.logSearch(term: term, type: "playlists", client: client.clientName, resultCount: result.count, error: nil)
                    return Array(result)
                }
                let results = YouTubeFeedParser.searchResults(in: json)
                if !results.playlists.isEmpty {
                    let result = results.playlists.prefix(limit).map { playlist in
                        YouTubePlaylist(
                            playlistId: playlist.playlistId,
                            title: playlist.title,
                            thumbnailURL: playlist.thumbnailURL,
                            videoCountText: playlist.videoCountText
                        )
                    }
                    DiagnosticLogger.shared.logSearch(term: term, type: "playlists", client: client.clientName, resultCount: result.count, error: nil)
                    return Array(result)
                }
            } catch {
                lastError = error
                DiagnosticLogger.shared.logSearch(term: term, type: "playlists", client: client.clientName, resultCount: 0, error: error.localizedDescription)
                continue
            }
        }
        searchError = lastError.map { "Playlist search failed: \($0.localizedDescription)" } ?? "Playlist search failed"
        DiagnosticLogger.shared.logSearch(term: term, type: "playlists", client: "all_failed", resultCount: 0, error: searchError)
        return []
    }

    func searchAlbums(term: String, limit: Int = 20) async -> [ParsedAlbum] {
        searchError = nil
        try? await client.ensureVisitorData()
        let clients: [YouTubeClient] = [config.defaultClient, .web, .iOS]
        var lastError: Error?
        for client in clients {
            do {
                let json = try await self.client.search(query: term, client: client)
                let albums = LibraryBrowseParser.parseAlbums(from: json)
                if !albums.isEmpty {
                    let result = Array(albums.prefix(limit))
                    DiagnosticLogger.shared.logSearch(term: term, type: "albums", client: client.clientName, resultCount: result.count, error: nil)
                    return result
                }
                // Albums in search results appear as lockupViewModel with contentType
                // containing ALBUM — handled by YouTubeFeedParser.playlists() which
                // also collects lockupViewModel entries.
                let results = YouTubeFeedParser.searchResults(in: json)
                if !results.playlists.isEmpty {
                    let result = results.playlists.prefix(limit).map { playlist in
                        ParsedAlbum(
                            browseId: playlist.playlistId,
                            title: playlist.title,
                            artist: playlist.channelTitle,
                            thumbnailUrl: playlist.thumbnailURL,
                            songCount: 0,
                            duration: 0,
                            playlistId: playlist.playlistId
                        )
                    }
                    DiagnosticLogger.shared.logSearch(term: term, type: "albums", client: client.clientName, resultCount: result.count, error: nil)
                    return result
                }
            } catch {
                lastError = error
                DiagnosticLogger.shared.logSearch(term: term, type: "albums", client: client.clientName, resultCount: 0, error: error.localizedDescription)
                continue
            }
        }
        searchError = lastError.map { "Album search failed: \($0.localizedDescription)" } ?? "Album search failed"
        DiagnosticLogger.shared.logSearch(term: term, type: "albums", client: "all_failed", resultCount: 0, error: searchError)
        return []
    }

    // MARK: - Playlist browsing

    func fetchPlaylistTracks(playlistID: String, limit: Int = 100) async -> (title: String?, tracks: [YouTubeTrack]) {
        let browseID = YouTubeFeeds.playlistBrowseId(playlistID)
        var rows: [[String: Any]] = []
        var title: String?
        var continuation: String?
        var seenContinuations = Set<String>()
        var pageCount = 0
        let clients: [YouTubeClient] = [config.defaultClient, .web, .iOS]

        try? await client.ensureVisitorData()

        do {
            repeat {
                let json: [String: Any]
                if let continuation {
                    json = try await client.browse(continuation: continuation)
                } else {
                    var lastError: Error?
                    var fetchedJson: [String: Any]?
                    for client in clients {
                        do {
                            fetchedJson = try await self.client.browse(browseId: browseID, client: client)
                            break
                        } catch {
                            lastError = error
                            continue
                        }
                    }
                    guard let fetchedJson else { throw lastError ?? InnerTubeError.invalidResponse }
                    json = fetchedJson
                }
                if title == nil { title = playlistTitle(from: json) }
                rows.append(contentsOf: LibraryBrowseParser.extractItems(from: json) ?? [])
                continuation = LibraryBrowseParser.extractContinuationToken(from: json)
                pageCount += 1
                if let continuation, !seenContinuations.insert(continuation).inserted {
                    throw InnerTubeError.truncatedResponse("Playlist returned a repeated page token.")
                }
                // Bound network and memory use for enormous playlists.
                if pageCount >= 20 || rows.count >= 500 { continuation = nil }
            } while continuation != nil

            var seenVideoIDs = Set<String>()
            let tracks = rows.compactMap { row -> YouTubeTrack? in
                guard let song = LibraryBrowseParser.parseSong(row),
                      seenVideoIDs.insert(song.videoId).inserted else { return nil }
                return YouTubeTrack(
                    videoId: song.videoId,
                    title: song.title,
                    artist: song.artists.joined(separator: ", "),
                    duration: Double(song.duration),
                    thumbnailURL: song.thumbnailUrl
                )
            }
            return (title, Array(tracks.prefix(max(1, limit))))
        } catch {
            searchError = "Playlist couldn't be loaded: \(error.localizedDescription)"
            return (title, [])
        }
    }

    private func playlistTitle(from json: [String: Any]) -> String? {
        guard let header = json["header"] as? [String: Any] else { return nil }
        for key in ["musicEditablePlaylistDetailHeaderRenderer", "musicPlaylistHeaderRenderer", "musicDetailHeaderRenderer"] {
            guard let renderer = header[key] as? [String: Any],
                  let title = renderer["title"] else { continue }
            if let text = title as? String, !text.isEmpty { return text }
            if let runs = title as? [String: Any],
               let parsed = InnerTubeJSON.runsText(runs), !parsed.isEmpty { return parsed }
        }
        return nil
    }

    // MARK: - Albums and artist pages

    func fetchAlbumTracks(browseID: String, limit: Int = 100) async -> (title: String?, artist: String?, tracks: [YouTubeTrack]) {
        do {
            let json = try await client.browse(browseId: browseID, client: config.defaultClient)
            let songs = LibraryBrowseParser.parseSongs(from: json)
            let tracks = songs.prefix(limit).map { song in
                YouTubeTrack(
                    videoId: song.videoId,
                    title: song.title,
                    artist: song.artists.joined(separator: ", "),
                    duration: Double(song.duration),
                    thumbnailURL: song.thumbnailUrl
                )
            }
            let header = json["header"] as? [String: Any]
            var title: String?
            var artist: String?
            for key in ["musicAlbumHeaderRenderer", "musicDetailHeaderRenderer", "musicImmersiveHeaderRenderer"] {
                guard let renderer = header?[key] as? [String: Any] else { continue }
                if title == nil {
                    title = (renderer["title"] as? String) ?? InnerTubeJSON.runsText(renderer["title"] as? [String: Any])
                }
                if artist == nil {
                    artist = InnerTubeJSON.runsText(renderer["subtitle"] as? [String: Any])
                }
            }
            return (title, artist, tracks)
        } catch {
            searchError = error.localizedDescription
            return (nil, nil, [])
        }
    }

    func fetchArtistTopTracks(channelID: String, limit: Int = 25) async -> (name: String?, tracks: [YouTubeTrack]) {
        do {
            let json = try await client.browse(browseId: channelID, client: config.defaultClient)
            let name = YouTubeFeedParser.channels(in: json).first?.title
            let videos = YouTubeFeedParser.videos(in: json)
            let tracks = videos.prefix(limit).map { video in
                YouTubeTrack(
                    videoId: video.videoId,
                    title: video.title,
                    artist: video.channelTitle ?? name ?? "Unknown Artist",
                    duration: video.durationSeconds.map { Double($0) } ?? 0,
                    thumbnailURL: video.thumbnailURL
                )
            }
            return (name, tracks)
        } catch {
            searchError = error.localizedDescription
            return (nil, [])
        }
    }

    // MARK: - Lyrics

    func fetchLyrics(videoId: String) async -> [YouTubeTranscriptSegment] {
        do {
            let playerJSON = try await client.player(videoId: videoId, client: config.defaultClient)
            let captionTracks = YouTubeWatchParser.captionTracks(in: playerJSON)
            guard let track = captionTracks.first(where: { $0.languageCode?.hasPrefix("en") == true && !$0.isAutoGenerated })
                    ?? captionTracks.first(where: { $0.languageCode?.hasPrefix("en") == true })
                    ?? captionTracks.first,
                  let baseURL = track.baseURL,
                  let urlString = YouTubeTranscript.json3URL(from: baseURL),
                  let url = URL(string: urlString) else { return [] }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            return YouTubeTranscript.segments(fromJSON3: data)
        } catch {
            return []
        }
    }

    // MARK: - Recommendations

    func recommendations(for videoId: String, limit: Int = 25) async -> [YouTubeTrack] {
        do {
            let json = try await client.next(videoId: videoId, client: config.defaultClient)
            let results = YouTubeFeedParser.searchResults(in: json)
            return results.videos.prefix(limit).map { video in
                YouTubeTrack(
                    videoId: video.videoId,
                    title: video.title,
                    artist: video.channelTitle ?? "Unknown Artist",
                    duration: video.durationSeconds.map { Double($0) } ?? 0,
                    thumbnailURL: video.thumbnailURL
                )
            }
        } catch {
            return []
        }
    }
}

struct YouTubeLibrarySnapshot {
    let tracks: [YouTubeTrack]
    let playlists: [YouTubePlaylist]
    let albums: [ParsedAlbum]
    let artists: [YouTubeChannel]
}

// MARK: - YouTube Track model

struct YouTubeTrack: Identifiable, Equatable, Hashable {
    let id: String
    let videoId: String
    var provider: String
    let title: String
    let artist: String
    let duration: Double
    let thumbnailURL: String?
    var streamURL: String?
    var localFileURL: String?

    init(videoId: String, title: String, artist: String, duration: Double = 0,
         thumbnailURL: String? = nil, streamURL: String? = nil,
         localFileURL: String? = nil, provider: String = "youtube") {
        self.id = videoId
        self.videoId = videoId
        self.provider = provider
        self.title = title
        self.artist = artist
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.streamURL = streamURL
        self.localFileURL = localFileURL
    }

    static func == (lhs: YouTubeTrack, rhs: YouTubeTrack) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let m = total / 60, s = total % 60
        return m > 0 ? "\(m):\(s < 10 ? "0" : "")\(s)" : "\(s)s"
    }
}
