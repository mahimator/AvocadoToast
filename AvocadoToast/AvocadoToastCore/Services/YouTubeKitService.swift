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

    // MARK: - Search

    func search(term: String, limit: Int = 25) async -> [YouTubeTrack] {
        isSearching = true
        searchError = nil
        defer { isSearching = false }

        do {
            let json = try await client.search(query: term, client: config.defaultClient)
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
            searchError = error.localizedDescription
            return []
        }
    }

    // MARK: - Stream resolution

    /// Resolves a playable audio stream URL for a YouTube video ID.
    func resolveStream(videoId: String) async -> String? {
        do {
            let result = try await StreamResolver.resolve(
                videoId: videoId,
                client: config.defaultClient,
                using: client,
                options: StreamResolveOptions(
                    forDownload: false,
                    audioQuality: .high,
                    videoQuality: .auto
                ),
                providers: StreamResolveProviders.none
            )
            return result.streamUrl
        } catch {
            searchError = "Stream resolution failed: \(error.localizedDescription)"
            return nil
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
    let title: String
    let artist: String
    let duration: Double
    let thumbnailURL: String?
    var streamURL: String?
    var isDownloaded: Bool = false
    var localFileURL: String?

    init(videoId: String, title: String, artist: String, duration: Double = 0,
         thumbnailURL: String? = nil, streamURL: String? = nil,
         isDownloaded: Bool = false, localFileURL: String? = nil) {
        self.id = videoId
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.streamURL = streamURL
        self.isDownloaded = isDownloaded
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
