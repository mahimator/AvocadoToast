//
//  CatalogService.swift
//  AvocadoToast
//
//  Backend-free catalog service using YouTubeKitService (SwiftyTube + InnerTube API).
//  Communicates directly with YouTube — no PC or backend server required.
//

import Foundation
import Combine

@MainActor
final class CatalogService: ObservableObject {
    static let shared = CatalogService()

    private let youtubeService: YouTubeKitService
    private let localAudioManager: LocalAudioManager
    private let audioPlayer: AudioPlayerService

    @Published var searchResults: [YouTubeTrack] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String?

    @Published var homeTracks: [YouTubeTrack] = []
    @Published var isLoadingHome: Bool = false

    // MARK: - Library (local persistence)

    @Published var savedTracks: [YouTubeTrack] = []

    func toggleSave(_ track: YouTubeTrack) {
        if let idx = savedTracks.firstIndex(where: { $0.videoId == track.videoId }) {
            savedTracks.remove(at: idx)
        } else {
            savedTracks.append(track)
        }
    }

    func isSaved(_ track: YouTubeTrack) -> Bool {
        savedTracks.contains { $0.videoId == track.videoId }
    }

    init(youtubeService: YouTubeKitService = .shared,
         localAudioManager: LocalAudioManager = .shared,
         audioPlayer: AudioPlayerService = .shared) {
        self.youtubeService = youtubeService
        self.localAudioManager = localAudioManager
        self.audioPlayer = audioPlayer
    }

    // MARK: - Search

    func search(query: String, type: SearchType? = nil, limit: Int = 25) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchError = "Query cannot be empty"
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchError = nil
        searchResults = []

        Task {
            let results = await youtubeService.search(term: query, limit: limit)
            guard !Task.isCancelled else { return }
            self.searchResults = results
            self.isSearching = false
        }
    }

    func searchYouTube(query: String, limit: Int = 25) async -> [YouTubeTrack] {
        await youtubeService.search(term: query, limit: limit)
    }

    func cancelSearch() {
        isSearching = false
    }

    // MARK: - Home

    func fetchHomeTracks() async {
        isLoadingHome = true
        defer { isLoadingHome = false }

        let trending = ["music 2024", "top songs", "popular music", "new releases"]
        var allTracks: [YouTubeTrack] = []

        for term in trending.prefix(3) {
            let results = await youtubeService.search(term: term, limit: 10)
            allTracks.append(contentsOf: results)
        }

        var seen = Set<String>()
        homeTracks = allTracks.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Stream resolution & playback

    func resolveStream(for track: YouTubeTrack) async -> String? {
        let streamURL = await youtubeService.resolveStream(videoId: track.videoId)
        return streamURL
    }

    func playTrack(_ track: YouTubeTrack) async {
        var trackToPlay = track
        if trackToPlay.streamURL == nil {
            let streamURL = await resolveStream(for: track)
            trackToPlay.streamURL = streamURL
        }

        if let localPath = localAudioManager.localFilePath(for: track.videoId) {
            trackToPlay.localFileURL = localPath
            trackToPlay.isDownloaded = true
        }

        await audioPlayer.play(trackToPlay)
    }

    func downloadTrack(_ track: YouTubeTrack) async {
        guard let streamURL = track.streamURL else {
            let resolved = await resolveStream(for: track)
            guard let resolvedURL = resolved else { return }
            await localAudioManager.download(track, streamURL: resolvedURL)
            return
        }
        await localAudioManager.download(track, streamURL: streamURL)
    }

    func toggleDownload(_ track: YouTubeTrack) async {
        if track.isDownloaded {
            localAudioManager.deleteLocalFile(videoId: track.videoId)
        } else {
            await downloadTrack(track)
        }
    }

    func getRecommendations(for track: YouTubeTrack) async -> [YouTubeTrack] {
        await youtubeService.recommendations(for: track.videoId)
    }

    // MARK: - Playback control

    func play() {
        audioPlayer.resume()
    }

    func pause() {
        audioPlayer.pause()
    }

    func togglePlayPause() {
        audioPlayer.togglePlayPause()
    }

    func stop() {
        audioPlayer.stop()
    }

    func seek(to time: Double) {
        audioPlayer.seek(to: time)
    }

    func setEQGain(band: Int, gain: Float) {
        audioPlayer.setEQGain(band: band, gain: gain)
    }

    func setEQPreset(_ preset: EQPreset) {
        audioPlayer.setEQPreset(preset)
    }
}

// MARK: - Search type

enum SearchType: String, CaseIterable {
    case songs = "songs"
    case videos = "videos"
    case albums = "albums"
    case artists = "artists"
    case playlists = "playlists"
    case all = "all"
}

// MARK: - Domain track (legacy compatibility)

struct DomainTrack: Identifiable, Equatable, Hashable {
    let id: String
    let provider: String
    let providerID: String
    let title: String
    let artistName: String
    let artistIDs: [String]
    let albumName: String?
    let albumID: String?
    let artworkURL: URL?
    let duration: Double?
    let isExplicit: Bool
    let isVideo: Bool
    let isPlayable: Bool

    init(id: String, provider: String, providerID: String, title: String, artistName: String,
         artistIDs: [String] = [], albumName: String? = nil, albumID: String? = nil,
         artworkURL: URL? = nil, duration: Double? = nil, isExplicit: Bool = false,
         isVideo: Bool = false, isPlayable: Bool = true) {
        self.id = id
        self.provider = provider
        self.providerID = providerID
        self.title = title
        self.artistName = artistName
        self.artistIDs = artistIDs
        self.albumName = albumName
        self.albumID = albumID
        self.artworkURL = artworkURL
        self.duration = duration
        self.isExplicit = isExplicit
        self.isVideo = isVideo
        self.isPlayable = isPlayable
    }

    static func == (lhs: DomainTrack, rhs: DomainTrack) -> Bool {
        lhs.id == rhs.id && lhs.provider == rhs.provider
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(provider)
    }
}

// MARK: - EQ preset

enum EQPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case vocal = "Vocal"
    case trebleBoost = "Treble Boost"
    case acoustic = "Acoustic"
    case electronic = "Electronic"

    var id: String { rawValue }

    var gains: [Float] {
        switch self {
        case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bassBoost: return [6, 4, 2, 0, -2, -4, -6, -8, -10, -12]
        case .vocal: return [-4, -2, 0, 2, 4, 2, 0, -2, -4, -6]
        case .trebleBoost: return [-12, -10, -8, -6, -4, -2, 0, 2, 4, 6]
        case .acoustic: return [-2, 0, 2, 4, 2, 0, -2, -4, -6, -8]
        case .electronic: return [4, 2, 0, -2, -4, 0, 2, 4, 2, 0]
        }
    }
}
