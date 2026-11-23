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

    // MARK: - Home discovery

    /// Returns the real YouTube Music Home response as a discovery source.
    /// Presentation and shelf selection stay owned by Avocado Toast.
    func fetchMusicHome() async throws -> [String: Any] {
        try await client.browse(browseId: "FEmusic_home", client: config.defaultClient)
    }

    // MARK: - Search

    func search(term: String, limit: Int = 25) async -> [YouTubeTrack] {
        isSearching = true
        searchError = nil
        defer { isSearching = false }

        do {
            let json = try await client.search(query: term, client: config.defaultClient)
            // Music search returns musicResponsiveListItemRenderer rows, not
            // ordinary videoRenderer rows. Parse Music rows first, then use the
            // general parser as a fallback for mixed/legacy results.
            let songs = LibraryBrowseParser.parseSongs(from: json)
            if !songs.isEmpty {
                var seen = Set<String>()
                return songs.filter { seen.insert($0.videoId).inserted }
                    .prefix(limit).map { song in
                        YouTubeTrack(
                            videoId: song.videoId,
                            title: song.title,
                            artist: song.artists.isEmpty ? "Unknown Artist" : song.artists.joined(separator: ", "),
                            duration: Double(song.duration),
                            thumbnailURL: song.thumbnailUrl
                        )
                    }
            }
            return YouTubeFeedParser.searchResults(in: json).videos.prefix(limit).map { video in
                YouTubeTrack(
                    videoId: video.videoId,
                    title: video.title,
                    artist: video.channelTitle ?? "Unknown Artist",
                    duration: video.durationSeconds.map { Double($0) } ?? 0,
                    thumbnailURL: video.thumbnailURL
                )
            }
        } catch {
            searchError = error.localizedDescription
            return []
        }
    }

    // MARK: - Stream resolution

    /// Resolves a playable audio stream URL for a YouTube video ID.
    func resolveStream(videoId: String) async -> String? {
        do {
            let request = StreamResolveRequest.playback(
                videoId: videoId,
                options: StreamResolveOptions(
                    forDownload: false,
                    audioQuality: .high,
                    videoQuality: .auto
                )
            )
            let result = try await StreamFallback.resolveFirstValid(
                request,
                using: client,
                providers: .none
            )
            return result.streamUrl
        } catch {
            searchError = "Stream resolution failed: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Typed catalog search

    func searchArtists(term: String, limit: Int = 20) async -> [YouTubeChannel] {
        searchError = nil
        do {
            let json = try await client.search(
                query: term,
                params: YouTubeSearchFilter.channel.rawValue,
                client: config.defaultClient
            )
            return LibraryBrowseParser.parseArtists(from: json).prefix(limit).map { artist in
                YouTubeChannel(
                    channelId: artist.channelId ?? artist.browseId,
                    title: artist.name,
                    thumbnailURL: artist.thumbnailUrl
                )
            }
        } catch {
            searchError = error.localizedDescription
            return []
        }
    }

    func searchPlaylists(term: String, limit: Int = 20) async -> [YouTubePlaylist] {
        searchError = nil
        do {
            let json = try await client.search(
                query: term,
                params: YouTubeSearchFilter.playlist.rawValue,
                client: config.defaultClient
            )
            return LibraryBrowseParser.parsePlaylists(from: json).prefix(limit).map { playlist in
                YouTubePlaylist(
                    playlistId: playlist.browseId,
                    title: playlist.title,
                    thumbnailURL: playlist.thumbnailUrl,
                    videoCountText: playlist.songCount.map { "\($0) songs" }
                )
            }
        } catch {
            searchError = error.localizedDescription
            return []
        }
    }

    // MARK: - Playlist browsing

    func fetchPlaylistTracks(playlistID: String, limit: Int = 100) async -> (title: String?, tracks: [YouTubeTrack]) {
        let browseID = YouTubeFeeds.playlistBrowseId(playlistID)
        var rows: [[String: Any]] = []
        var title: String?
        var continuation: String?
        var seenContinuations = Set<String>()
        var pageCount = 0

        do {
            repeat {
                let json: [String: Any]
                if let continuation {
                    json = try await client.browse(continuation: continuation)
                } else {
                    json = try await client.browse(browseId: browseID, client: config.defaultClient)
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

    func searchAlbums(term: String, limit: Int = 20) async -> [ParsedAlbum] {
        searchError = nil
        do {
            let json = try await client.search(query: term, client: config.defaultClient)
            return Array(LibraryBrowseParser.parseAlbums(from: json).prefix(limit))
        } catch {
            searchError = error.localizedDescription
            return []
        }
    }

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
