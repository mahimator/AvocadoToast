//
//  ArtistDetailView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import Combine

/// Artist detail screen: artwork, bio, top tracks, albums and singles.
struct ArtistDetailView: View {
    let artistID: String
    @StateObject private var viewModel = ArtistDetailViewModel()
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let artist = viewModel.artist {
                artistContent(artist)
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Artist not found", systemImage: "person.crop.circle")
            }
        }
        .navigationTitle(viewModel.artist?.name ?? "Artist")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(artistID: artistID) }
    }

    @ViewBuilder
    private func artistContent(_ artist: ArtistResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                artworkView(artist)

                VStack(alignment: .leading, spacing: 8) {
                    Text(artist.name)
                        .font(.title2.weight(.bold))
                    if !artist.genres.isEmpty {
                        Text(artist.genres.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let description = artist.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button(action: { viewModel.playTopTracks() }) {
                        Label("Play Top Tracks", systemImage: "play.circle.fill")
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

                // Top tracks
                if !artist.topTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Tracks")
                            .font(.headline)
                            .padding(.horizontal)
                        ForEach(Array(artist.topTracks.enumerated()), id: \.element.id) { index, track in
                            ArtistTrackRow(track: track, number: index + 1)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.playTrack(track)
                                }
                        }
                    }
                }

                // Albums
                if !artist.albums.isEmpty {
                    sectionHeader("Albums")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(artist.albums, id: \.id) { album in
                                ArtistAlbumCard(album: album)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Singles
                if !artist.singles.isEmpty {
                    sectionHeader("Singles")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(artist.singles, id: \.id) { album in
                                ArtistAlbumCard(album: album)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Related artists
                if !artist.relatedArtists.isEmpty {
                    sectionHeader("Related Artists")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(artist.relatedArtists, id: \.id) { related in
                                RelatedArtistCard(artist: related)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 20)
            }
        }
    }

    @ViewBuilder
    private func artworkView(_ artist: ArtistResponse) -> some View {
        if let artworkURL = artist.artworkURL.flatMap({ URL(string: $0) }) {
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

// MARK: - Subviews

struct ArtistTrackRow: View {
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
                Text(track.albumName ?? "Single")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
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

struct ArtistAlbumCard: View {
    let album: AlbumResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artworkURL = album.artworkURL.flatMap({ URL(string: $0) }) {
                CachedAsyncImage(url: artworkURL, size: CGSize(width: 120, height: 120)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
            Text(album.title)
                .font(.body.weight(.medium))
                .lineLimit(2)
        }
        .frame(width: 120)
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 120, height: 120)
    }
}

struct RelatedArtistCard: View {
    let artist: ArtistResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artworkURL = artist.artworkURL.flatMap({ URL(string: $0) }) {
                CachedAsyncImage(url: artworkURL, size: CGSize(width: 100, height: 100)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
            Text(artist.name)
                .font(.body.weight(.medium))
                .lineLimit(2)
        }
        .frame(width: 100)
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 100, height: 100)
    }
}

// MARK: - Artist detail view model

@MainActor
final class ArtistDetailViewModel: ObservableObject {
    @Published var artist: ArtistResponse?
    @Published var isLoading: Bool = false
    @Published var isSaved: Bool = false

    private let catalogService: CatalogService

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    func load(artistID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            artist = try await catalogService.fetchArtist(id: artistID)
        } catch {
            print("Artist load failed: \(error)")
        }
    }

    func playTopTracks() {
        guard let artist = artist else { return }
        let tracks = artist.topTracks.map { DomainTrack(from: $0) }
        PlayerService.shared.setQueue(tracks, startAt: 0)
        PlayerService.shared.playEngine()
    }

    func playTrack(_ track: TrackResponse) {
        PlayerService.shared.play(DomainTrack(from: track))
    }

    func toggleSave() {
        guard let artist = artist else { return }
        let saved = LibraryService.shared.savedArtists
        let already = saved.contains { $0.id == artist.id && $0.provider == artist.provider }
        if already {
            if let existing = saved.first(where: { $0.id == artist.id && $0.provider == artist.provider }) {
                LibraryService.shared.removeArtist(existing)
            }
        } else {
            let model = ArtistModel(
                id: artist.id, provider: artist.provider, providerID: artist.providerID,
                name: artist.name, artworkURL: artist.artworkURL,
                artistDescription: artist.description, genres: artist.genres,
                albums: artist.albums.map { a in
                    AlbumModel(id: a.id, provider: a.provider, providerID: a.providerID,
                               title: a.title, artistName: a.artist, artistIDs: a.artistIDs,
                               artworkURL: a.artworkURL, releaseDate: a.releaseDate,
                               trackCount: a.trackCount, albumType: a.albumType,
                               tracks: a.tracks.map { t in
                                   TrackModel(id: t.id, provider: t.provider, providerID: t.providerID,
                                              title: t.title, artistName: t.artistName,
                                              artistIDs: t.artistIDs, albumName: t.albumName,
                                              albumID: t.albumID, artworkURL: t.artworkURL,
                                              duration: t.duration, explicit: t.explicit,
                                              isVideo: t.isVideo, isPlayable: t.isPlayable)
                               },
                               metadata: a.metadata ?? [:], providerIdentifiers: a.providerIdentifiers ?? [:])
                },
                singles: artist.singles.map { a in
                    AlbumModel(id: a.id, provider: a.provider, providerID: a.providerID,
                               title: a.title, artistName: a.artist, artistIDs: a.artistIDs,
                               artworkURL: a.artworkURL, releaseDate: a.releaseDate,
                               trackCount: a.trackCount, albumType: a.albumType,
                               tracks: a.tracks.map { t in
                                   TrackModel(id: t.id, provider: t.provider, providerID: t.providerID,
                                              title: t.title, artistName: t.artistName,
                                              artistIDs: t.artistIDs, albumName: t.albumName,
                                              albumID: t.albumID, artworkURL: t.artworkURL,
                                              duration: t.duration, explicit: t.explicit,
                                              isVideo: t.isVideo, isPlayable: t.isPlayable)
                               },
                               metadata: a.metadata ?? [:], providerIdentifiers: a.providerIdentifiers ?? [:])
                },
                topTracks: artist.topTracks.map { t in
                    TrackModel(id: t.id, provider: t.provider, providerID: t.providerID,
                               title: t.title, artistName: t.artistName, artistIDs: t.artistIDs,
                               albumName: t.albumName, albumID: t.albumID, artworkURL: t.artworkURL,
                               duration: t.duration, explicit: t.explicit, isVideo: t.isVideo,
                               isPlayable: t.isPlayable)
                },
                relatedArtists: artist.relatedArtists.map { r in
                    ArtistModel(id: r.id, provider: r.provider, providerID: r.providerID,
                                name: r.name, artworkURL: r.artworkURL,
                                artistDescription: r.description, genres: r.genres)
                },
                metadata: artist.metadata ?? [:], providerIdentifiers: artist.providerIdentifiers ?? [:]
            )
            LibraryService.shared.saveArtist(model)
        }
        isSaved = LibraryService.shared.isArtistSaved(id: artist.id, provider: artist.provider)
    }
}
