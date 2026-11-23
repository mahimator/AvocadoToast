//
//  SearchView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import Combine

/// Search screen: debounced catalog search with category filtering,
/// recent searches, and result navigation.
struct SearchView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = SearchViewModel()

    @State private var query: String = ""
    @State private var selectedType: SearchType = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Category selector
                categorySelector
                    .padding(.horizontal)

                // Content
                Group {
                    if CatalogService.shared.isSearching {
                        searchingView
                    } else if let error = CatalogService.shared.searchError, !error.isEmpty {
                        errorView(error)
                    } else if query.isEmpty && viewModel.recentSearches.isEmpty {
                        emptyPrompt
                    } else if query.isEmpty {
                        recentSearchesView
                    } else if CatalogService.shared.searchResults.isEmpty {
                        emptyResults
                    } else {
                        resultsList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: query) { _, newValue in
                viewModel.debounceSearch(newValue)
            }
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search songs, artists, albums…", text: $query)
                .textInputAutocapitalization(.none)
                .submitLabel(.search)
                .onSubmit {
                    viewModel.searchNow(query)
                }
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorTokens.separator.opacity(0.4), lineWidth: 1)
        )
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SearchType.allCases, id: \.rawValue) { type in
                    Button(action: { selectedType = type }) {
                        Text(type.rawValue.capitalized)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedType == type ? Color.accentColor : Color.secondary.opacity(0.12))
                            .cornerRadius(20)
                    }
                    .foregroundStyle(selectedType == type ? .white : .primary)
                }
            }
            .padding(.horizontal)
        }
    }

    private var searchingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching…")
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView("Search Error", systemImage: "wifi.exclamationmark", description: Text(error))
    }

    private var emptyPrompt: some View {
        ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Type a song, artist, album or playlist"))
    }

    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Searches")
                .font(.headline)
                .padding(.horizontal)
            if viewModel.recentSearches.isEmpty {
                Text("No recent searches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else {
                ForEach(viewModel.recentSearches, id: \.self) { recent in
                    Button(action: {
                        query = recent
                        viewModel.searchNow(recent)
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(recent)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    }
                }
                Button(action: { viewModel.clearHistory() }) {
                    Text("Clear History")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyResults: some View {
        ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No matches for “\(query)”"))
    }

    private var resultsList: some View {
        List(CatalogService.shared.searchResults) { result in
            Button(action: {
                viewModel.select(result)
                if result.entityType.lowercased() == "song" {
                    playSong(result)
                } else {
                    coordinator.path.append(destination(for: result))
                }
            }) {
                SearchResultRow(result: result)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(action: { viewModel.toggleSave(result) }) {
                    Text(viewModel.isSaved(result) ? "Remove from Library" : "Save to Library")
                }
            }
        }
        .listStyle(.plain)
    }

    private func destination(for result: SearchResult) -> NavigationDestination {
        switch result.entityType.lowercased() {
        case "album": return .albumDetail(result.id)
        case "artist": return .artistDetail(result.id)
        case "playlist": return .playlistDetail(result.id)
        default: return .miniPlayer(result.id)
        }
    }

    private func playSong(_ result: SearchResult) {
        let domain = DomainTrack(
            id: result.id,
            provider: result.provider,
            providerID: result.id,
            title: result.title,
            artistName: result.artist,
            artistIDs: [],
            albumName: result.album,
            albumID: nil,
            artworkURL: result.artworkURL.flatMap { URL(string: $0) },
            duration: result.duration,
            isExplicit: result.isExplicit,
            isVideo: false,
            isPlayable: result.isPlayable
        )
        PlayerService.shared.play(domain)
        coordinator.showingNowPlaying = true
    }
}

// MARK: - Search result row

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            if let artworkURL = result.artworkURL.flatMap({ URL(string: $0) }) {
                CachedAsyncImage(url: artworkURL, size: CGSize(width: 56, height: 56)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(result.displayArtist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(result.formattedDuration)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Search view model

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var recentSearches: [String] = []

    private let searchService: SearchService

    init(searchService: SearchService = .shared) {
        self.searchService = searchService
        self.recentSearches = searchService.recentSearches
    }

    func debounceSearch(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            guard !Task.isCancelled else { return }
            searchNow(query)
        }
    }

    private var searchTask: Task<Void, Never>?

    func searchNow(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        CatalogService.shared.search(query: query, type: nil, limit: 30)
    }

    func select(_ result: SearchResult) {
        searchService.addRecent(result.title)
        refreshRecents()
    }

    func toggleSave(_ result: SearchResult) {
        let domain = DomainTrack(
            id: result.id,
            provider: result.provider,
            providerID: result.id,
            title: result.title,
            artistName: result.artist,
            artistIDs: [],
            albumName: result.album,
            albumID: nil,
            artworkURL: result.artworkURL.flatMap { URL(string: $0) },
            duration: result.duration,
            isExplicit: result.isExplicit,
            isVideo: false,
            isPlayable: result.isPlayable
        )
        LibraryService.shared.toggleSave(domain)
    }

    func isSaved(_ result: SearchResult) -> Bool {
        LibraryService.shared.savedTracks.contains { $0.id == result.id && $0.provider == result.provider }
    }

    func clearHistory() {
        searchService.clearHistory()
        refreshRecents()
    }

    private func refreshRecents() {
        recentSearches = searchService.recentSearches
    }
}
