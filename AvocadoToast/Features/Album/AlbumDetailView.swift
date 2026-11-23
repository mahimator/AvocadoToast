//
//  AlbumDetailView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import Combine

/// Album detail screen: artwork, metadata, track list and actions.
struct AlbumDetailView: View {
    let albumID: String
    @StateObject private var viewModel = AlbumDetailViewModel()
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let album = viewModel.album {
                albumContent(album)
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Album not found", systemImage: "square.dashed")
            }
        }
        .navigationTitle(viewModel.album?.title ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(albumID: albumID) }
    }

    @ViewBuilder
    private func albumContent(_ album: AlbumResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Artwork
                artworkView(album)

                VStack(alignment: .leading, spacing: 8) {
                    Text(album.title)
                        .font(.title2.weight(.bold))
                    Text(album.artist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if let releaseDate = album.releaseDate, !releaseDate.isEmpty {
                        Text("Released \(releaseDate)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(album.trackCount) tracks · \(album.albumType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Actions
                HStack(spacing: 16) {
                    Button(action: { viewModel.playAlbum() }) {
                        Label("Play Album", systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { viewModel.toggleSave() }) {
                        Label(viewModel.isSaved ? "Saved" : "Save", systemImage: viewModel.isSaved ? "checkmark" : "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                // Track list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracks")
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                        AlbumTrackRow(track: track, number: index + 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.playTrack(track)
                            }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func artworkView(_ album: AlbumResponse) -> some View {
        if let artworkURL = album.artworkURL.flatMap({ URL(string: $0) }) {
            CachedAsyncImage(url: artworkURL, size: CGSize(width: 300, height: 300)) { image in
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                } else {
                    placeholderArtwork
                }
            }
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 300, height: 300)
    }
}

// MARK: - Album track row

struct AlbumTrackRow: View {
    let track: TrackResponse
    let number: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)

            if let artworkURL = track.artworkURL.flatMap({ URL(string: $0) }) {
                CachedAsyncImage(url: artworkURL, size: CGSize(width: 44, height: 44)) { image in
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
                Text(track.title)
                    .font(.body)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let duration = track.duration {
                Text(duration.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
    @Published var album: AlbumResponse?
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false

    private let catalogService: CatalogService

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    func load(albumID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            album = try await catalogService.fetchAlbum(id: albumID)
        } catch {
            print("Album load failed: \(error)")
        }
    }

    func playAlbum() {
        guard let album = album else { return }
        let tracks = album.tracks.map { DomainTrack(from: $0) }
        PlayerService.shared.setQueue(tracks, startAt: 0)
        PlayerService.shared.playEngine()
    }

    func playTrack(_ track: TrackResponse) {
        let domain = DomainTrack(from: track)
        PlayerService.shared.play(domain)
    }

    func toggleSave() {
        guard let album = album else { return }
        let saved = LibraryService.shared.savedAlbums
        let already = saved.contains { $0.id == album.id && $0.provider == album.provider }
        if already {
            if let existing = saved.first(where: { $0.id == album.id && $0.provider == album.provider }) {
                LibraryService.shared.removeAlbum(existing)
            }
        } else {
            let model = AlbumModel(
                id: album.id, provider: album.provider, providerID: album.providerID,
                title: album.title, artistName: album.artist, artistIDs: album.artistIDs,
                artworkURL: album.artworkURL, releaseDate: album.releaseDate,
                trackCount: album.trackCount, albumType: album.albumType,
                tracks: album.tracks.map { track in
                    TrackModel(id: track.id, provider: track.provider, providerID: track.providerID,
                               title: track.title, artistName: track.artistName,
                               artistIDs: track.artistIDs, albumName: track.albumName,
                               albumID: track.albumID, artworkURL: track.artworkURL,
                               duration: track.duration, explicit: track.explicit,
                               isVideo: track.isVideo, isPlayable: track.isPlayable)
                },
                metadata: album.metadata ?? [:], providerIdentifiers: album.providerIdentifiers ?? [:]
            )
            LibraryService.shared.saveAlbum(model)
        }
        isSaved = LibraryService.shared.isAlbumSaved(id: album.id, provider: album.provider)
    }
}
