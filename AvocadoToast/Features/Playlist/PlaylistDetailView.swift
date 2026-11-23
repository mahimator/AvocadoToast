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
        .navigationTitle(viewModel.playlist?.first?.title ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(playlistID: playlistID) }
    }

    @ViewBuilder
    private func playlistContent(_ playlist: [YouTubeTrack]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(playlist.first?.title ?? "Playlist")
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
                        Label(viewModel.isSaved ? "Saved" : "Save", systemImage: viewModel.isSaved ? "checkmark" : "plus")
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
                        ForEach(playlist) { track in
                            PlaylistTrackRow(track: track)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task { await CatalogService.shared.playTrack(track) }
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
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false

    private let catalogService: CatalogService

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    func load(playlistID: String) async {
        isLoading = true
        defer { isLoading = false }
        // In a real app, this would fetch a playlist by ID from YouTube
        // For now, we search for the playlist ID as a query
        let results = await catalogService.searchYouTube(query: playlistID, limit: 20)
        self.playlist = results
    }

    func playAll() {
        guard let playlist, !playlist.isEmpty else { return }
        Task { await CatalogService.shared.playQueue(playlist) }
    }

    func toggleSaveAll() {
        guard let playlist = playlist else { return }
        for track in playlist {
            CatalogService.shared.toggleSave(track)
        }
        isSaved = CatalogService.shared.isSaved(playlist.first ?? YouTubeTrack(videoId: "", title: "", artist: ""))
    }
}
