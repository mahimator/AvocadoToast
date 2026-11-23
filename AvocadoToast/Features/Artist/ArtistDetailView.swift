//
//  ArtistDetailView.swift
//  AvocadoToast
//
//  Artist detail using YouTube tracks.
//

import SwiftUI
import Combine

struct ArtistDetailView: View {
    let query: String
    @StateObject private var viewModel = ArtistDetailViewModel()
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let tracks = viewModel.tracks, !tracks.isEmpty {
                artistContent(tracks)
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Artist not found", systemImage: "person.crop.circle")
            }
        }
        .navigationTitle(viewModel.artistName ?? "Artist")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(query: query) }
    }

    @ViewBuilder
    private func artistContent(_ tracks: [YouTubeTrack]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.artistName ?? "Artist")
                        .font(.title2.weight(.bold))
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
                        Label("Play All", systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        viewModel.toggleSaveAll()
                    }) {
                        Label(viewModel.isSaved ? "Saved" : "Save", systemImage: viewModel.isSaved ? "checkmark" : "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Tracks")
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        ArtistTrackRow(track: track, number: index + 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { await CatalogService.shared.playTrack(track) }
                            }
                    }
                }

                Spacer(minLength: 20)
            }
        }
    }
}

// MARK: - Artist track row

struct ArtistTrackRow: View {
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

// MARK: - Artist detail view model

@MainActor
final class ArtistDetailViewModel: ObservableObject {
    @Published var tracks: [YouTubeTrack]?
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false
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
        self.artistName = results.first?.artist
    }

    func playAll() {
        guard let playlist = tracks else { return }
        if let first = playlist.first {
            Task { await CatalogService.shared.playTrack(first) }
        }
    }

    func toggleSaveAll() {
        guard let playlist = tracks else { return }
        for track in playlist {
            CatalogService.shared.toggleSave(track)
        }
        isSaved = CatalogService.shared.isSaved(playlist.first ?? YouTubeTrack(videoId: "", title: "", artist: ""))
    }
}
