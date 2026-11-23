//
//  PlaylistDetailView.swift
//  AvocadoToast
//
//  Playlist detail using YouTube tracks.
//

import SwiftUI
import Combine

struct PlaylistDetailView: View {
    let playlistID: String
    @StateObject private var viewModel = PlaylistDetailViewModel()
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let playlist = viewModel.playlist {
                playlistContent(playlist)
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Playlist not found", systemImage: "music.note.list")
            }
        }
        .navigationTitle(viewModel.playlistTitle ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(playlistID: playlistID) }
    }

    @ViewBuilder
    private func playlistContent(_ playlist: [YouTubeTrack]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.playlistTitle ?? "Playlist")
                        .font(.title2.weight(.bold))
                    Text("\(playlist.count) tracks")
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
                        Label(viewModel.isSaved ? "Tracks saved" : "Save tracks", systemImage: viewModel.isSaved ? "checkmark" : "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                if !playlist.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tracks")
                            .font(.headline)
                            .padding(.horizontal)
                        ForEach(playlist.indices, id: \.self) { index in
                            let track = playlist[index]
                            PlaylistTrackRow(track: track)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task { await CatalogService.shared.playQueue(playlist, startAt: index) }
                                }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
        }
    }
}

// MARK: - Playlist track row

struct PlaylistTrackRow: View {
    let track: YouTubeTrack

    var body: some View {
        HStack(spacing: 12) {
            Text("").frame(width: 24)
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

// MARK: - Playlist view model

@MainActor
final class PlaylistDetailViewModel: ObservableObject {
    @Published var playlist: [YouTubeTrack]?
    @Published var playlistTitle: String?
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false

    private let catalogService: CatalogService

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    func load(playlistID: String) async {
        isLoading = true
        defer { isLoading = false }
        let result = await YouTubeKitService.shared.fetchPlaylistTracks(playlistID: playlistID)
        self.playlistTitle = result.title
        self.playlist = result.tracks
        if let first = result.tracks.first {
            isSaved = result.tracks.allSatisfy { catalogService.isSaved($0) }
        } else {
            isSaved = false
        }
    }

    func playAll() {
        guard let playlist, !playlist.isEmpty else { return }
        Task { await CatalogService.shared.playQueue(playlist) }
    }

    func toggleSaveAll() {
        guard let playlist, !playlist.isEmpty else { return }
        let catalog = CatalogService.shared
        let allSaved = playlist.allSatisfy { catalog.isSaved($0) }
        for track in playlist {
            if allSaved && catalog.isSaved(track) {
                catalog.toggleSave(track)
            } else if !allSaved && !catalog.isSaved(track) {
                catalog.toggleSave(track)
            }
        }
        isSaved = playlist.allSatisfy { catalog.isSaved($0) }
    }
}
