//
//  PlaylistDetailView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import Combine

/// Playlist detail screen: artwork, metadata, track list and playback actions.
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
        .navigationTitle(viewModel.playlist?.title ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(playlistID: playlistID) }
    }

    @ViewBuilder
    private func playlistContent(_ playlist: PlaylistResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                artworkView(playlist)

                VStack(alignment: .leading, spacing: 8) {
                    Text(playlist.title)
                        .font(.title2.weight(.bold))
                    if let description = playlist.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(playlist.trackCount) tracks · \(playlist.creator)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button(action: { viewModel.playPlaylist() }) {
                        Label("Play Playlist", systemImage: "play.circle.fill")
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

                if !playlist.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tracks")
                            .font(.headline)
                            .padding(.horizontal)
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            PlaylistTrackRow(track: track, number: index + 1)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.playTrack(track)
                                }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
        }
    }

    @ViewBuilder
    private func artworkView(_ playlist: PlaylistResponse) -> some View {
        if let artworkURL = playlist.artworkURL.flatMap({ URL(string: $0) }) {
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

// MARK: - Playlist track row

struct PlaylistTrackRow: View {
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
                Text(track.title).font(.body).lineLimit(1)
                Text(track.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let duration = track.duration {
                Text(duration.formattedDuration)
                    .font(.caption).foregroundStyle(.secondary)
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

// MARK: - Playlist detail view model

@MainActor
final class PlaylistDetailViewModel: ObservableObject {
    @Published var playlist: PlaylistResponse?
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false

    private let catalogService: CatalogService

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    func load(playlistID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            playlist = try await catalogService.fetchPlaylist(id: playlistID)
        } catch {
            print("Playlist load failed: \(error)")
        }
    }

    func playPlaylist() {
        guard let playlist = playlist else { return }
        let tracks = playlist.tracks.map { DomainTrack(from: $0) }
        PlayerService.shared.setQueue(tracks, startAt: 0)
        PlayerService.shared.playEngine()
    }

    func playTrack(_ track: TrackResponse) {
        PlayerService.shared.play(DomainTrack(from: track))
    }

    func toggleSave() {
        guard let playlist = playlist else { return }
        let saved = LibraryService.shared.savedPlaylists
        let already = saved.contains { $0.id == playlist.id && $0.provider == playlist.provider }
        if already {
            if let existing = saved.first(where: { $0.id == playlist.id && $0.provider == playlist.provider }) {
                LibraryService.shared.deletePlaylist(existing)
            }
        } else {
            let model = PlaylistModel(
                id: playlist.id, name: playlist.title,
                playlistDescription: playlist.description,
                artworkURL: playlist.artworkURL, creator: playlist.creator,
                provider: playlist.provider, providerID: playlist.providerID,
                trackIDs: playlist.tracks.map { $0.id },
                tracks: playlist.tracks.map { t in
                    TrackModel(id: t.id, provider: t.provider, providerID: t.providerID,
                               title: t.title, artistName: t.artistName, artistIDs: t.artistIDs,
                               albumName: t.albumName, albumID: t.albumID, artworkURL: t.artworkURL,
                               duration: t.duration, explicit: t.explicit, isVideo: t.isVideo,
                               isPlayable: t.isPlayable)
                },
                isEditable: playlist.isEditable,
                metadata: playlist.metadata ?? [:], providerIdentifiers: playlist.providerIdentifiers ?? [:]
            )
            LibraryService.shared.savePlaylist(model)
        }
        isSaved = LibraryService.shared.savedPlaylists.contains { $0.id == playlist.id && $0.provider == playlist.provider }
    }
}
