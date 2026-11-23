//
//  CatalogService.swift
//  AvocadoToast
//
//  Backend-free catalog service using YouTubeKitService (SwiftyTube + InnerTube API).
//  Communicates directly with YouTube — no PC or backend server required.
//

import Foundation
import Combine

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

    var canPlayPrevious: Bool { queueIndex > 0 || repeatMode == .all || (shuffleEnabled && !shuffleHistory.isEmpty) }
    var canPlayNext: Bool { (shuffleEnabled && playbackQueue.count > 1 && (!shuffleDeck.isEmpty || repeatMode == .all)) || queueIndex + 1 < playbackQueue.count || repeatMode == .all }

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
        isLoadingHome = true
        defer { isLoadingHome = false }

        let trending = ["new music", "popular songs", "new releases"]
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
        var prepared = track
        if track.provider != "local" && prepared.streamURL == nil {
            prepared.streamURL = await resolveStream(for: prepared)
        }
        await audioPlayer.play(prepared)
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
            if shuffleDeck.isEmpty && repeatMode == .all {
                shuffleDeck = playbackQueue.indices.filter { $0 != queueIndex }.shuffled()
            }
            guard let shuffledNext = shuffleDeck.first else { return }
            shuffleDeck.removeFirst()
            nextIndex = shuffledNext
            shuffleHistory.append(queueIndex)
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
            return
        }
        playbackQueue = Array(playbackQueue.prefix(queueIndex + 1))
        resetShuffleState()
    }

    func playPrevious() {
        guard !playbackQueue.isEmpty else { return }
        if audioPlayer.currentTime > 3 {
            Task { await playQueueItem(playbackQueue[queueIndex]) }
            return
        }
        let previousIndex: Int
        if shuffleEnabled, let historic = shuffleHistory.popLast() {
            shuffleDeck.insert(queueIndex, at: 0)
            queueIndex = historic
            Task { await playQueueItem(playbackQueue[queueIndex]) }
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
                shuffleHistory.append(queueIndex)
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
        audioPlayer.stop()
        playbackQueue.removeAll()
        queueIndex = 0
        shuffleHistory.removeAll()
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
