//
//  CatalogService.swift
//  AvocadoToast
//
//  Backend-free catalog service using YouTubeKitService (SwiftyTube + InnerTube API).
//  Communicates directly with YouTube — no PC or backend server required.
//

import Foundation
import Combine
import SwiftyTube

enum QueueRepeatMode: String, CaseIterable {
    case off, all, one
}

@MainActor
final class CatalogService: ObservableObject {
    static let shared = CatalogService()

    private let youtubeService: YouTubeKitService
    private let audioPlayer: AudioPlayerService

    @Published var searchResults: [YouTubeTrack] = []
    @Published var artistSearchResults: [YouTubeChannel] = []
    @Published var albumSearchResults: [ParsedAlbum] = []
    @Published var playlistSearchResults: [YouTubePlaylist] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String?

    @Published var homeTracks: [YouTubeTrack] = []
    @Published var isLoadingHome: Bool = false
    @Published var homeError: String?

    // MARK: - Library (local persistence)

    @Published var savedTracks: [YouTubeTrack] = []

    // Queue state belongs to the catalog/player boundary, not individual screens.
    @Published private(set) var playbackQueue: [YouTubeTrack] = []
    @Published private(set) var queueIndex: Int = 0
    @Published var shuffleEnabled: Bool = false
    @Published var repeatMode: QueueRepeatMode = .off

    private var searchTask: Task<Void, Never>?
    private var activeSearchID: UUID?
    private var shuffleHistory: [Int] = []
    private var shuffleDeck: [Int] = []
    private var homeRequestID: UUID?
    private var playbackRequestID: UUID?

    var canPlayPrevious: Bool { shuffleEnabled ? !shuffleHistory.isEmpty : (queueIndex > 0 || repeatMode == .all) }
    var canPlayNext: Bool { (shuffleEnabled && playbackQueue.count > 1) || queueIndex + 1 < playbackQueue.count || repeatMode == .all }

    func refreshSavedTracks() {
        let library = LibraryService.shared
        library.refresh()
        savedTracks = library.savedTracks
            .filter { $0.provider == "youtube" || $0.provider == "local" }
            .map { item in
                YouTubeTrack(
                    videoId: item.provider == "local" ? item.id : (item.providerID.isEmpty ? item.id : item.providerID),
                    title: item.title,
                    artist: item.artistName,
                    duration: item.duration ?? 0,
                    thumbnailURL: item.artworkURL,
                    localFileURL: item.provider == "local" ? item.providerID : nil,
                    provider: item.provider
                )
            }
    }

    func toggleSave(_ track: YouTubeTrack) {
        LibraryService.shared.toggleSaveYouTubeTrack(track)
        refreshSavedTracks()
    }

    func isSaved(_ track: YouTubeTrack) -> Bool {
        LibraryService.shared.isTrackSaved(id: track.videoId, provider: track.provider)
    }

    init(youtubeService: YouTubeKitService = .shared,
         audioPlayer: AudioPlayerService = .shared) {
        self.youtubeService = youtubeService
        self.audioPlayer = audioPlayer
        refreshSavedTracks()
        audioPlayer.onPlaybackFinished = { [weak self] in
            Task { @MainActor in self?.advanceQueueAfterCompletion() }
        }
        audioPlayer.onPlaybackNext = { [weak self] in self?.playNext() }
        audioPlayer.onPlaybackPrevious = { [weak self] in self?.playPrevious() }
        audioPlayer.onPlaybackRetry = { [weak self] in
            guard let self, self.playbackQueue.indices.contains(self.queueIndex) else { return }
            let retryTrack = self.playbackQueue[self.queueIndex]
            Task { await self.playQueueItem(retryTrack) }
        }
    }

    // MARK: - Search

    func search(query: String, type: SearchType = .songs, limit: Int = 25) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        activeSearchID = nil

        guard !trimmed.isEmpty else {
            searchError = nil
            searchResults = []
            artistSearchResults = []
            albumSearchResults = []
            playlistSearchResults = []
            isSearching = false
            return
        }

        let requestID = UUID()
        activeSearchID = requestID
        isSearching = true
        searchError = nil
        searchResults = []
        artistSearchResults = []
        albumSearchResults = []
        playlistSearchResults = []

        searchTask = Task { [weak self, youtubeService = self.youtubeService] in
            switch type {
            case .songs:
                let results = await youtubeService.search(term: trimmed, limit: limit)
                guard !Task.isCancelled, let self, self.activeSearchID == requestID else { return }
                self.searchResults = results
            case .albums:
                let results = await youtubeService.searchAlbums(term: trimmed, limit: limit)
                guard !Task.isCancelled, let self, self.activeSearchID == requestID else { return }
                self.albumSearchResults = results
            case .artists:
                let results = await youtubeService.searchArtists(term: trimmed, limit: limit)
                guard !Task.isCancelled, let self, self.activeSearchID == requestID else { return }
                self.artistSearchResults = results
            case .playlists:
                let results = await youtubeService.searchPlaylists(term: trimmed, limit: limit)
                guard !Task.isCancelled, let self, self.activeSearchID == requestID else { return }
                self.playlistSearchResults = results
            }
            guard let self, self.activeSearchID == requestID else { return }
            self.searchError = youtubeService.searchError
            self.isSearching = false
            self.searchTask = nil
            self.activeSearchID = nil
        }
    }

    func searchYouTube(query: String, limit: Int = 25) async -> [YouTubeTrack] {
        await youtubeService.search(term: query, limit: limit)
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        activeSearchID = nil
        isSearching = false
    }

    // MARK: - Home

    func fetchHomeTracks() async {
        let requestID = UUID()
        homeRequestID = requestID
        isLoadingHome = true
        homeError = nil
        defer {
            if homeRequestID == requestID {
                isLoadingHome = false
                homeRequestID = nil
            }
        }

        // Avocado Toast is not a YouTube Music clone. Use the real Music Home
        // feed as a discovery source, then curate its shelves into one small,
        // music-first pool instead of replacing the screen with YTM's layout.
        do {
            let json = try await youtubeService.fetchMusicHome()
            guard homeRequestID == requestID else { return }

            let shelves = YouTubeFeedParser.shelves(in: json)
            DiagnosticLogger.shared.write("HOME shelves found: \(shelves.count)")
            for shelf in shelves.prefix(10) {
                DiagnosticLogger.shared.write("HOME shelf title='\(shelf.title ?? "nil")' videos=\(shelf.videos.count) playlists=\(shelf.playlists.count)")
            }
            let excludedShelfTerms = ["shorts", "podcast", "news", "gaming", "kids", "live"]
            let preferredShelfTerms = [
                "mix", "quick picks", "recommended", "for you", "listen again",
                "new music", "new releases", "music", "song", "album", "playlist", "radio"
            ]

            let filteredShelves = shelves.filter { shelf in
                let title = (shelf.title ?? "").lowercased()
                return !excludedShelfTerms.contains(where: title.contains)
            }
            let preferredShelves = filteredShelves.filter { shelf in
                let title = (shelf.title ?? "").lowercased()
                return preferredShelfTerms.contains(where: title.contains)
            }
            let sourceShelves = preferredShelves.isEmpty ? filteredShelves : preferredShelves

            var candidates: [YouTubeTrack] = []
            DiagnosticLogger.shared.write("HOME sourceShelves count: \(sourceShelves.count)")
            for shelf in sourceShelves {
                for video in shelf.videos where !video.isShort && !video.isLive {
                    let title = video.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty, !video.videoId.isEmpty else { continue }
                    candidates.append(YouTubeTrack(
                        videoId: video.videoId,
                        title: title,
                        artist: video.channelTitle ?? "Unknown Artist",
                        duration: video.durationSeconds.map { Double($0) } ?? 0,
                        thumbnailURL: video.thumbnailURL
                    ))
                }
            }
            DiagnosticLogger.shared.write("HOME candidates from shelves: \(candidates.count)")

            // Some Home responses expose video renderers without shelf wrappers.
            // Keep that as a fallback, still sourced from the actual Home feed.
            if candidates.isEmpty {
                candidates = YouTubeFeedParser.videos(in: json)
                    .filter { !$0.isShort && !$0.isLive && !$0.videoId.isEmpty && !$0.title.isEmpty }
                    .map { video in
                        YouTubeTrack(
                            videoId: video.videoId,
                            title: video.title,
                            artist: video.channelTitle ?? "Unknown Artist",
                            duration: video.durationSeconds.map { Double($0) } ?? 0,
                            thumbnailURL: video.thumbnailURL
                        )
                    }
            }

            var seen = Set<String>()
            homeTracks = candidates.filter { seen.insert($0.videoId).inserted }.prefix(36).map { $0 }
            DiagnosticLogger.shared.logHome(success: true, trackCount: homeTracks.count, error: nil)
        } catch {
            guard homeRequestID == requestID else { return }
            // Preserve the last good feed so a transient network/API failure
            // does not blank the home screen during refresh.
            homeError = error.localizedDescription
            DiagnosticLogger.shared.logHome(success: false, trackCount: 0, error: error.localizedDescription)
        }
    }

    // MARK: - Stream resolution & playback

    func resolveStream(for track: YouTubeTrack) async -> String? {
        let streamURL = await youtubeService.resolveStream(videoId: track.videoId)
        return streamURL
    }

    /// Starts a single track and resets queue context to that item.
    func playTrack(_ track: YouTubeTrack) async {
        playbackQueue = [track]
        queueIndex = 0
        resetShuffleState()
        await playQueueItem(track)
    }

    /// Starts a queue, optionally at a selected track. Queue controls operate on
    /// this state so screens don't independently invent playback behaviour.
    func playQueue(_ tracks: [YouTubeTrack], startAt index: Int = 0) async {
        guard !tracks.isEmpty else { return }
        playbackQueue = tracks
        queueIndex = min(max(index, 0), tracks.count - 1)
        resetShuffleState()
        await playQueueItem(playbackQueue[queueIndex])
    }

    private func playQueueItem(_ track: YouTubeTrack) async {
        let requestID = UUID()
        playbackRequestID = requestID
        var prepared = track
        if track.provider != "local" && prepared.streamURL == nil {
            prepared.streamURL = await resolveStream(for: prepared)
        }
        guard playbackRequestID == requestID else { return }
        await audioPlayer.play(prepared)
        guard playbackRequestID == requestID else { return }
        if audioPlayer.isPlaying { LibraryService.shared.recordPlayed(track) }
    }

    func addToQueue(_ track: YouTubeTrack) {
        if playbackQueue.isEmpty || audioPlayer.currentTrack == nil {
            Task { await playTrack(track) }
            return
        }
        playbackQueue.append(track)
        resetShuffleState()
    }

    func playNextInQueue(_ track: YouTubeTrack) {
        if playbackQueue.isEmpty || audioPlayer.currentTrack == nil {
            Task { await playTrack(track) }
            return
        }
        let insertion = min(queueIndex + 1, playbackQueue.count)
        playbackQueue.insert(track, at: insertion)
        resetShuffleState()
    }

    func playNext() {
        guard !playbackQueue.isEmpty else { return }
        let nextIndex: Int
        if shuffleEnabled && playbackQueue.count > 1 {
            if shuffleDeck.isEmpty {
                shuffleDeck = playbackQueue.indices.filter { $0 != queueIndex }.shuffled()
            }
            guard let shuffledNext = shuffleDeck.first else { return }
            shuffleDeck.removeFirst()
            nextIndex = shuffledNext
            recordShuffleHistory(queueIndex)
        } else if queueIndex + 1 < playbackQueue.count {
            nextIndex = queueIndex + 1
        } else if repeatMode == .all {
            nextIndex = 0
        } else {
            return
        }
        queueIndex = nextIndex
        Task { await playQueueItem(playbackQueue[nextIndex]) }
    }

    /// Removes a queued item without disturbing the currently playing item.
    func removeQueuedTrack(at index: Int) {
        guard playbackQueue.indices.contains(index), index != queueIndex else { return }
        playbackQueue.remove(at: index)
        if index < queueIndex { queueIndex -= 1 }
        resetShuffleState()
    }

    /// Keeps the current item and clears everything scheduled after it.
    func clearUpcoming() {
        guard playbackQueue.indices.contains(queueIndex) else {
            playbackQueue.removeAll()
            queueIndex = 0
            resetShuffleState()
            return
        }
        if shuffleEnabled {
            let currentTrack = playbackQueue[queueIndex]
            playbackQueue = [currentTrack]
            queueIndex = 0
        } else {
            playbackQueue = Array(playbackQueue.prefix(queueIndex + 1))
        }
        resetShuffleState()
    }

    func playPrevious() {
        guard !playbackQueue.isEmpty else { return }
        if audioPlayer.currentTime > 3 {
            Task { await playQueueItem(playbackQueue[queueIndex]) }
            return
        }
        let previousIndex: Int
        if shuffleEnabled {
            if let historic = shuffleHistory.popLast() {
                shuffleDeck.insert(queueIndex, at: 0)
                queueIndex = historic
                Task { await playQueueItem(playbackQueue[queueIndex]) }
            } else if repeatMode == .all && playbackQueue.count > 1 {
                Task { await playQueueItem(playbackQueue[queueIndex]) }
            }
            return
        }
        if queueIndex > 0 {
            previousIndex = queueIndex - 1
        } else if repeatMode == .all {
            previousIndex = playbackQueue.count - 1
        } else {
            return
        }
        queueIndex = previousIndex
        Task { await playQueueItem(playbackQueue[queueIndex]) }
    }

    func toggleShuffle() {
        shuffleEnabled.toggle()
        resetShuffleState()
    }

    private func resetShuffleState() {
        shuffleHistory.removeAll()
        shuffleDeck.removeAll()
        if shuffleEnabled {
            shuffleDeck = playbackQueue.indices.filter { $0 != queueIndex }.shuffled()
        }
    }

    private func recordShuffleHistory(_ index: Int) {
        shuffleHistory.append(index)
        let historyLimit = max(100, playbackQueue.count * 3)
        if shuffleHistory.count > historyLimit {
            shuffleHistory.removeFirst(shuffleHistory.count - historyLimit)
        }
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    private func advanceQueueAfterCompletion() {
        guard !playbackQueue.isEmpty else { return }
        if repeatMode == .one {
            Task { await playQueueItem(playbackQueue[queueIndex]) }
        } else if shuffleEnabled && playbackQueue.count > 1 {
            if shuffleDeck.isEmpty && repeatMode == .all {
                shuffleDeck = playbackQueue.indices.filter { $0 != queueIndex }.shuffled()
            }
            if let next = shuffleDeck.first {
                shuffleDeck.removeFirst()
                recordShuffleHistory(queueIndex)
                queueIndex = next
                Task { await playQueueItem(playbackQueue[queueIndex]) }
            }
        } else if queueIndex + 1 < playbackQueue.count {
            queueIndex += 1
            Task { await playQueueItem(playbackQueue[queueIndex]) }
        } else if repeatMode == .all {
            queueIndex = 0
            Task { await playQueueItem(playbackQueue[queueIndex]) }
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
        playbackRequestID = nil
        audioPlayer.stop()
        playbackQueue.removeAll()
        queueIndex = 0
        resetShuffleState()
    }

    func seek(to time: Double) {
        audioPlayer.seek(to: time)
    }

}

// MARK: - Search type

enum SearchType: String, CaseIterable, Identifiable {
    case songs, albums, artists, playlists
    var id: String { rawValue }
    var title: String {
        switch self {
        case .songs: "Songs"
        case .albums: "Albums"
        case .artists: "Artists"
        case .playlists: "Playlists"
        }
    }
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
