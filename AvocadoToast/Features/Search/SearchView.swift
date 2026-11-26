//
//  SearchView.swift
//  AvocadoToast
//
//  Catalog search with warm surfaces and honest empty/loading/error states.
//

import SwiftUI
import Combine
import SwiftyTube

struct SearchView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var catalog = CatalogService.shared
    @ObservedObject private var config = AppConfig.shared
    @StateObject private var viewModel = SearchViewModel()
    @State private var query = ""
    @State private var selectedCategory: SearchType = .songs

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                Text("Search the music catalog")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)

                Picker("Search media", selection: $config.searchMediaMode) {
                    ForEach(AppConfig.SearchMediaMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.top, 12)

                categoryPicker
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                Group {
                    if CatalogService.shared.isSearching {
                        loadingState
                    } else if let error = CatalogService.shared.searchError, !error.isEmpty {
                        ContentUnavailableView("Couldn't find a slice of that", systemImage: "wifi.exclamationmark", description: Text(error))
                    } else if query.isEmpty {
                        if recentSearches.isEmpty {
                            searchPrompt
                        } else {
                            recentSearchesView
                        }
                    } else if !hasResults {
                        VStack(spacing: 8) {
                            AvocadoMascotView(mood: .searching)
                            Text("Nothing in the search basket")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("Try a different name or switch between Audio and Video.")
                                .font(.subheadline)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 280)
                        }
                    } else {
                        searchResultsView
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
                if value.isEmpty {
                    viewModel.cancelSearch()
                } else {
                    viewModel.debounceSearch(value, type: selectedCategory)
                }
            }
            .onChange(of: selectedCategory) { _, category in
                if !query.isEmpty { viewModel.searchNow(query, type: category) }
            }
            .onChange(of: config.searchMediaMode) { _, _ in
                if !query.isEmpty { viewModel.searchNow(query, type: selectedCategory) }
            }
        }
    }

    private var categoryPicker: some View {
        Picker("Search category", selection: $selectedCategory) {
            ForEach(SearchType.allCases) { category in
                Text(category.title).tag(category)
            }
        }
        .pickerStyle(.segmented)
    }

    private var hasResults: Bool {
        switch selectedCategory {
        case .songs: !CatalogService.shared.searchResults.isEmpty
        case .albums: !CatalogService.shared.albumSearchResults.isEmpty
        case .artists: !CatalogService.shared.artistSearchResults.isEmpty
        case .playlists: !CatalogService.shared.playlistSearchResults.isEmpty
        }
    }

    @ViewBuilder
    private var searchResultsView: some View {
        switch selectedCategory {
        case .songs: songsResults
        case .albums: albumsResults
        case .artists: artistsResults
        case .playlists: playlistsResults
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
                .onSubmit { viewModel.searchNow(query, type: selectedCategory) }
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
        .background(config.enableGlassEffects ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(ColorTokens.backgroundSecondary), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        VStack(spacing: 8) {
            AvocadoMascotView(mood: .searching)
            Text("Find your next favorite")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Search for a song, artist, album or playlist.")
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
        }
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
                    if query == term {
                        viewModel.searchNow(term, type: selectedCategory)
                    } else {
                        query = term
                    }
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

    private var albumsResults: some View {
        List {
            ForEach(CatalogService.shared.albumSearchResults, id: \.browseId) { album in
                NavigationLink {
                    AlbumDetailView(query: album.browseId)
                } label: {
                    HStack(spacing: 12) {
                        if let url = album.thumbnailUrl.flatMap(URL.init(string:)) {
                            CachedAsyncImage(url: url, size: CGSize(width: 56, height: 56)) { image in
                                if let image {
                                    Image(uiImage: image).resizable().scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else { searchArtworkPlaceholder }
                            }
                        } else { searchArtworkPlaceholder }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.title).font(.body.weight(.semibold)).lineLimit(2)
                            Text(album.artist ?? (album.songCount > 0 ? "\(album.songCount) songs" : "Album"))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    Button {
                        saveAlbumToLibrary(album)
                    } label: {
                        Label("Save album to Library", systemImage: "square.stack")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.backgroundPrimary)
    }

    private var artistsResults: some View {
        List {
            ForEach(CatalogService.shared.artistSearchResults, id: \.title) { artist in
                NavigationLink {
                    ArtistDetailView(query: artist.channelId ?? artist.title)
                } label: {
                    HStack(spacing: 12) {
                        if let url = artist.thumbnailURL.flatMap(URL.init(string:)) {
                            CachedAsyncImage(url: url, size: CGSize(width: 56, height: 56)) { image in
                                if let image {
                                    Image(uiImage: image).resizable().scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else { searchArtworkPlaceholder }
                            }
                        } else { searchArtworkPlaceholder }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artist.title).font(.body.weight(.semibold)).lineLimit(1)
                            Text(artist.handle ?? artist.subscriberCountText ?? "Artist")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    Button {
                        saveArtistToLibrary(artist)
                    } label: {
                        Label("Save artist to Library", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.backgroundPrimary)
    }

    private var playlistsResults: some View {
        List {
            ForEach(CatalogService.shared.playlistSearchResults, id: \.playlistId) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlistID: playlist.playlistId)
                } label: {
                    HStack(spacing: 12) {
                        if let url = playlist.thumbnailURL.flatMap(URL.init(string:)) {
                            CachedAsyncImage(url: url, size: CGSize(width: 56, height: 56)) { image in
                                if let image {
                                    Image(uiImage: image).resizable().scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else { searchArtworkPlaceholder }
                            }
                        } else { searchArtworkPlaceholder }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlist.title).font(.body.weight(.semibold)).lineLimit(2)
                            Text(playlist.channelTitle ?? playlist.videoCountText ?? "Playlist")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    Button {
                        savePlaylistToLibrary(playlist)
                    } label: {
                        Label("Save playlist to Library", systemImage: "bookmark")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.backgroundPrimary)
    }

    private func savePlaylistToLibrary(_ playlist: YouTubePlaylist) {
        let model = PlaylistModel(
            id: playlist.playlistId,
            name: playlist.title,
            artworkURL: playlist.thumbnailURL,
            creator: playlist.channelTitle ?? "YouTube Music",
            provider: "youtube",
            providerID: playlist.playlistId,
            isEditable: false,
            metadata: ["trackCount": playlist.videoCountText ?? "Playlist"]
        )
        LibraryService.shared.savePlaylist(model)
    }

    private func saveAlbumToLibrary(_ album: ParsedAlbum) {
        let model = AlbumModel(
            id: album.browseId,
            provider: "youtube",
            providerID: album.browseId,
            title: album.title,
            artistName: album.artist ?? "Unknown Artist",
            artworkURL: album.thumbnailUrl,
            trackCount: album.songCount,
            albumType: "album"
        )
        LibraryService.shared.saveAlbum(model)
    }

    private func saveArtistToLibrary(_ artist: YouTubeChannel) {
        let providerID = artist.channelId ?? artist.title
        let model = ArtistModel(
            id: providerID,
            provider: "youtube",
            providerID: providerID,
            name: artist.title,
            artworkURL: artist.thumbnailURL,
            genres: [],
            metadata: ["handle": artist.handle ?? "", "channelId": artist.channelId ?? ""]
        )
        LibraryService.shared.saveArtist(model)
    }

    private var searchArtworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(ColorTokens.artworkPlaceholder)
            .frame(width: 56, height: 56)
            .overlay(Image(systemName: "music.note").foregroundStyle(ColorTokens.textSecondary))
    }

    private var songsResults: some View {
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
                        CatalogService.shared.playNextInQueue(track)
                    } label: {
                        Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    Button {
                        CatalogService.shared.addToQueue(track)
                    } label: {
                        Label("Add to queue", systemImage: "text.badge.plus")
                    }
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

    func debounceSearch(_ text: String, type: SearchType = .songs) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            searchNow(text, type: type)
        }
    }

    func cancelSearch() {
        debounceTask?.cancel()
        debounceTask = nil
        searchService.cancelSearch()
    }

    func searchNow(_ text: String, type: SearchType = .songs) {
        debounceTask?.cancel()
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            searchService.cancelSearch()
            return
        }
        searchService.addRecent(cleaned)
        recentSearches = searchService.recentSearches
        CatalogService.shared.search(query: cleaned, type: type)
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
