//
//  SearchView.swift
//  AvocadoToast
//
//  Native catalog search. Category filters are intentionally withheld until the
//  underlying provider query supports them, rather than presenting fake filters.
//

import SwiftUI
import Combine

struct SearchView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = SearchViewModel()
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                Text("Songs, artists, albums and playlists")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

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
            .onAppear {
                query = coordinator.searchQuery
                if !query.isEmpty { viewModel.searchNow(query) }
            }
            .onChange(of: query) { _, newValue in
                coordinator.searchQuery = newValue
                viewModel.debounceSearch(newValue)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search music", text: $query)
                .textInputAutocapitalization(.none)
                .submitLabel(.search)
                .onSubmit { viewModel.searchNow(query) }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }

    private var searchingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching catalog…").foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView("Search unavailable", systemImage: "wifi.exclamationmark", description: Text(error))
    }

    private var emptyPrompt: some View {
        ContentUnavailableView("Find your next track", systemImage: "magnifyingglass", description: Text("Search a song, artist, album, or playlist."))
    }

    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent searches").font(.headline)
                Spacer()
                Button("Clear") { viewModel.clearHistory() }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            ForEach(viewModel.recentSearches, id: \.self) { recent in
                Button {
                    query = recent
                    viewModel.searchNow(recent)
                } label: {
                    Label(recent, systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyResults: some View {
        ContentUnavailableView("No results", systemImage: "music.note.magnifyingglass", description: Text("No matches for “\(query)”"))
    }

    private var resultsList: some View {
        List(CatalogService.shared.searchResults) { track in
            Button {
                viewModel.select(track)
                Task { await CatalogService.shared.playTrack(track) }
            } label: {
                SearchResultRow(track: track)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    CatalogService.shared.toggleSave(track)
                } label: {
                    Label(CatalogService.shared.isSaved(track) ? "Remove from Library" : "Save to Library", systemImage: "heart")
                }
            }
        }
        .listStyle(.plain)
    }
}

struct SearchResultRow: View {
    let track: YouTubeTrack

    var body: some View {
        HStack(spacing: 12) {
            if let url = track.thumbnailURL.flatMap(URL.init(string:)) {
                CachedAsyncImage(url: url, size: CGSize(width: 56, height: 56)) { image in
                    if let image {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                    } else { placeholderArtwork }
                }
            } else { placeholderArtwork }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title).font(.body.weight(.medium)).lineLimit(1)
                Text(track.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Text(track.formattedDuration).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 5)
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.15)).frame(width: 56, height: 56)
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var recentSearches: [String] = []
    private let searchService: SearchService
    private var searchTask: Task<Void, Never>?

    init(searchService: SearchService = .shared) {
        self.searchService = searchService
        recentSearches = searchService.recentSearches
    }

    func debounceSearch(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            searchNow(query)
        }
    }

    func searchNow(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        CatalogService.shared.search(query: query)
    }

    func select(_ track: YouTubeTrack) {
        searchService.addRecent(track.title)
        recentSearches = searchService.recentSearches
    }

    func clearHistory() {
        searchService.clearHistory()
        recentSearches = searchService.recentSearches
    }
}
