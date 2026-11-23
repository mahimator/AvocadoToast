//
//  SearchView.swift
//  AvocadoToast
//
//  Catalog search with warm surfaces and honest empty/loading/error states.
//

import SwiftUI
import Combine

struct SearchView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = SearchViewModel()
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                Text("Songs, artists, albums and playlists")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)

                Group {
                    if CatalogService.shared.isSearching {
                        loadingState
                    } else if let error = CatalogService.shared.searchError, !error.isEmpty {
                        ContentUnavailableView("Couldn't find a slice of that", systemImage: "wifi.exclamationmark", description: Text(error))
                    } else if query.isEmpty {
                        recentSearches.isEmpty ? searchPrompt : recentSearchesView
                    } else if CatalogService.shared.searchResults.isEmpty {
                        ContentUnavailableView("No matches this time", systemImage: "music.note.magnifyingglass", description: Text("Try another artist, track or album."))
                    } else {
                        resultsList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                query = coordinator.searchQuery
                if !query.isEmpty {
                    viewModel.searchNow(query)
                }
            }
            .onChange(of: query) { _, value in
                coordinator.searchQuery = value
                viewModel.debounceSearch(value)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ColorTokens.textSecondary)
            TextField("What sounds good?", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { viewModel.searchNow(query) }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(ColorTokens.separator)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(ColorTokens.accentPrimary)
            Text("Looking around the catalog…")
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var searchPrompt: some View {
        ContentUnavailableView("Find your next favorite", systemImage: "magnifyingglass", description: Text("Search for a song, artist, album or playlist."))
    }

    private var recentSearches: [String] { viewModel.recentSearches }

    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent searches")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Button("Clear") { viewModel.clearHistory() }
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(.horizontal, 18)
            ForEach(recentSearches, id: \.self) { term in
                Button {
                    query = term
                    viewModel.searchNow(term)
                } label: {
                    Label(term, systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(ColorTokens.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 20)
    }

    private var resultsList: some View {
        List {
            ForEach(CatalogService.shared.searchResults) { track in
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
                        Label(
                            CatalogService.shared.isSaved(track) ? "Remove from Library" : "Save to Library",
                            systemImage: CatalogService.shared.isSaved(track) ? "heart.slash" : "heart"
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.backgroundPrimary)
    }
}

struct SearchResultRow: View {
    let track: YouTubeTrack

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
                Text(track.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.textSecondary.opacity(0.8))
            }
            Spacer(minLength: 6)
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var artwork: some View {
        if let url = track.thumbnailURL.flatMap({ URL(string: $0) }) {
            CachedAsyncImage(url: url, size: CGSize(width: 56, height: 56)) { image in
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    artworkPlaceholder
                }
            }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(ColorTokens.artworkPlaceholder)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(width: 56, height: 56)
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var recentSearches: [String] = []
    private let searchService: SearchService
    private var debounceTask: Task<Void, Never>?

    init(searchService: SearchService = .shared) {
        self.searchService = searchService
        recentSearches = searchService.recentSearches
    }

    func debounceSearch(_ text: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            searchNow(text)
        }
    }

    func searchNow(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            searchService.cancelSearch()
            return
        }
        searchService.addRecent(cleaned)
        recentSearches = searchService.recentSearches
        CatalogService.shared.search(query: cleaned)
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
