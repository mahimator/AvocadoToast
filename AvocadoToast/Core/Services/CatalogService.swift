//
//  CatalogService.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import Combine

/// Central catalog service. All catalog access goes through the backend API
/// (never directly to ytmusicapi from the client). Results are normalized into
/// app-domain models before being handed to the UI.
@MainActor
final class CatalogService: ObservableObject {
    static let shared = CatalogService()

    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var searchError: String?

    @Published var homeSections: [HomeSection] = []
    @Published var isLoadingHome: Bool = false

    let apiClient: APIClient
    private var currentSearchTask: Task<Void, Never>?

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Search

    func search(query: String, type: SearchType? = nil, limit: Int = 20) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchError = "Query cannot be empty"
            searchResults = []
            isSearching = false
            return
        }
        guard trimmed.count <= 200 else {
            searchError = "Query too long (max 200 characters)"
            searchResults = []
            isSearching = false
            return
        }

        // Cancel any in-flight search so stale results never overwrite newer ones
        currentSearchTask?.cancel()

        isSearching = true
        searchError = nil

        currentSearchTask = Task {
            do {
                let apiResults: [SearchResult] = try await apiClient.request(
                    .search(query: trimmed, type: type, limit: limit)
                )
                // Guard against cancellation / stale response
                guard !Task.isCancelled else { return }
                self.searchResults = apiResults
            } catch is CancellationError {
                // Expected when a newer search supersedes this one
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.searchError = error.localizedDescription
                self.searchResults = []
            }
            self.isSearching = false
        }
    }

    func cancelSearch() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
        isSearching = false
    }

    // MARK: - Home

    func fetchHomeSections() async {
        isLoadingHome = true
        defer { isLoadingHome = false }
        do {
            let response: HomeResponse = try await apiClient.request(.home)
            self.homeSections = response.sections
        } catch {
            // Home is non-critical; keep showing cached / empty sections
            self.homeSections = []
        }
    }

    // MARK: - Details

    func fetchTrack(id: String) async throws -> TrackResponse {
        try await apiClient.request(.song(id: id))
    }

    func fetchAlbum(id: String) async throws -> AlbumResponse {
        try await apiClient.request(.album(id: id))
    }

    func fetchArtist(id: String) async throws -> ArtistResponse {
        try await apiClient.request(.artist(id: id))
    }

    func fetchPlaylist(id: String) async throws -> PlaylistResponse {
        try await apiClient.request(.playlist(id: id))
    }

    func fetchRelated(id: String) async throws -> [MusicEntity] {
        try await apiClient.request(.related(id: id))
    }

    func fetchLyrics(id: String) async throws -> LyricsResponse {
        try await apiClient.request(.lyrics(id: id))
    }

    func fetchCharts() async throws -> ChartsResponse {
        try await apiClient.request(.charts)
    }

    func checkHealth() async throws -> HealthResponse {
        try await apiClient.request(.health)
    }
}

// MARK: - Domain track wrapper (used by player / library)

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

    init(from api: TrackResponse) {
        self.id = api.id
        self.provider = api.provider
        self.providerID = api.providerID
        self.title = api.title
        self.artistName = api.artistName
        self.artistIDs = api.artistIDs
        self.albumName = api.albumName
        self.albumID = api.albumID
        self.artworkURL = api.artworkURL.flatMap { URL(string: $0) }
        self.duration = api.duration
        self.isExplicit = api.explicit ?? false
        self.isVideo = api.isVideo
        self.isPlayable = api.isPlayable
    }

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

// MARK: - Convenience extensions on API search result

extension SearchResult {
    var entityType: String { type }
    var duration: Double? { durationSeconds }
    var isExplicit: Bool { explicit ?? false }
    var isPlayable: Bool { playable }
    var formattedDuration: String {
        guard let d = durationSeconds, d > 0 else { return "—" }
        let total = Int(d)
        let m = total / 60, s = total % 60
        return m > 0 ? "\(m):\(s < 10 ? "0" : "")\(s)" : "\(s)s"
    }
    var displayArtist: String { artist.isEmpty ? "Unknown Artist" : artist }
    var displayAlbum: String { album ?? "Single" }
}

