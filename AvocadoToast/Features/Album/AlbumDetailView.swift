//
//  AlbumDetailView.swift
//  AvocadoToast
//
//  Album detail using YouTube tracks.
//

import SwiftUI
import Combine

struct AlbumDetailView: View {
    let query: String
    @StateObject private var viewModel = AlbumDetailViewModel()
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let tracks = viewModel.tracks, !tracks.isEmpty {
                albumContent(tracks)
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Album not found", systemImage: "square.dashed")
            }
        }
        .navigationTitle(viewModel.albumTitle ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(query: query) }
    }

    @ViewBuilder
    private func albumContent(_ tracks: [YouTubeTrack]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.albumTitle ?? "Album")
                        .font(.title2.weight(.bold))
                    Text(viewModel.artistName ?? "Various Artists")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("\(tracks.count) tracks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button(action: {
                        Task { await viewModel.playAll() }
                    }) {
                        Label("Play Album", systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        viewModel.toggleSaveAll()
                    }) {
                        Label(viewModel.isSaved ? "Tracks saved" : "Save tracks", systemImage: viewModel.isSaved ? "checkmark" : "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracks")
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        AlbumTrackRow(track: track, number: index + 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { await CatalogService.shared.playQueue(tracks, startAt: index) }
                            }
                    }
                }

                Spacer(minLength: 20)
            }
        }
    }
}

// MARK: - Album track row

struct AlbumTrackRow: View {
    let track: YouTubeTrack
    let number: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            if let thumbnailURL = track.thumbnailURL, let url = URL(string: thumbnailURL) {
                CachedAsyncImage(url: url, size: CGSize(width: 44, height: 44)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).font(.body).lineLimit(1)
                Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(track.formattedDuration)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 44, height: 44)
    }
}

// MARK: - Album detail view model

@MainActor
final class AlbumDetailViewModel: ObservableObject {
    @Published var tracks: [YouTubeTrack]?
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false
    @Published var albumTitle: String?
    @Published var artistName: String?

    private let catalogService: CatalogService

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    func load(query: String) async {
        isLoading = true
        defer { isLoading = false }
        let results = await catalogService.searchYouTube(query: query, limit: 20)
        self.tracks = results
        self.albumTitle = results.first?.title ?? query
        self.artistName = results.first?.artist
        self.isSaved = !results.isEmpty && results.allSatisfy { catalogService.isSaved($0) }
    }

    func playAll() {
        guard let tracks, !tracks.isEmpty else { return }
        Task { await CatalogService.shared.playQueue(tracks) }
    }

    func toggleSaveAll() {
        guard let tracks, !tracks.isEmpty else { return }
        let catalog = CatalogService.shared
        let allSaved = tracks.allSatisfy { catalog.isSaved($0) }
        for track in tracks {
            if allSaved && catalog.isSaved(track) {
                catalog.toggleSave(track)
            } else if !allSaved && !catalog.isSaved(track) {
                catalog.toggleSave(track)
            }
        }
        isSaved = tracks.allSatisfy { catalog.isSaved($0) }
    }
}
