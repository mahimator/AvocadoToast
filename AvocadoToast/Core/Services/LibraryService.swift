//
//  LibraryService.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import Combine
import SwiftData

/// Library service backed by SwiftData. All saved music lives locally and
/// survives application restarts. It does not depend on an active
/// YouTube Music login.
@MainActor
final class LibraryService: ObservableObject {
    static let shared = LibraryService()

    private let context: ModelContext

    @Published private(set) var savedTracks: [TrackModel] = []
    @Published private(set) var savedAlbums: [AlbumModel] = []
    @Published private(set) var savedArtists: [ArtistModel] = []
    @Published private(set) var savedPlaylists: [PlaylistModel] = []
    @Published private(set) var recentlyPlayed: [TrackModel] = []

    init(context: ModelContext? = nil) {
        if let context {
            self.context = context
        } else {
            self.context = PersistenceController.shared.context
        }
        refresh()
    }

    // MARK: - Refresh

    func refresh() {
        do {
            savedTracks = try context.fetch(FetchDescriptor<TrackModel>(
                sortBy: [SortDescriptor(\TrackModel.addedAt, order: .reverse)]
            ))
            savedAlbums = try context.fetch(FetchDescriptor<AlbumModel>(
                sortBy: [SortDescriptor(\AlbumModel.title)]
            ))
            savedArtists = try context.fetch(FetchDescriptor<ArtistModel>(
                sortBy: [SortDescriptor(\ArtistModel.name)]
            ))
            savedPlaylists = try context.fetch(FetchDescriptor<PlaylistModel>(
                sortBy: [SortDescriptor(\PlaylistModel.updatedAt, order: .reverse)]
            ))
            recentlyPlayed = try context.fetch(FetchDescriptor<TrackModel>(
                sortBy: [SortDescriptor(\TrackModel.lastPlayedAt, order: .reverse)]
            ))
        } catch {
            print("LibraryService refresh failed: \(error)")
        }
    }

    // MARK: - Tracks

    func saveTrack(_ track: TrackModel) {
        // Avoid duplicates by internal id
        let exists = savedTracks.contains { $0.id == track.id && $0.provider == track.provider }
        guard !exists else { return }
        context.insert(track)
        save()
        refresh()
    }

    func saveTrack(from domain: DomainTrack) {
        let track = TrackModel(
            id: domain.id,
            provider: domain.provider,
            providerID: domain.providerID,
            title: domain.title,
            artistName: domain.artistName,
            artistIDs: domain.artistIDs,
            albumName: domain.albumName,
            albumID: domain.albumID,
            artworkURL: domain.artworkURL?.absoluteString,
            duration: domain.duration,
            explicit: domain.isExplicit,
            isVideo: domain.isVideo,
            isPlayable: domain.isPlayable,
            addedAt: Date(),
            playCount: 0
        )
        saveTrack(track)
    }

    func removeTrack(_ track: TrackModel) {
        context.delete(track)
        save()
        refresh()
    }

    func removeTrack(by id: String, provider: String) {
        guard let track = savedTracks.first(where: { $0.id == id && $0.provider == provider }) else { return }
        removeTrack(track)
    }

    func isTrackSaved(id: String, provider: String) -> Bool {
        savedTracks.contains { $0.id == id && $0.provider == provider }
    }

    func toggleSave(_ domain: DomainTrack) {
        if isTrackSaved(id: domain.id, provider: domain.provider) {
            removeTrack(by: domain.id, provider: domain.provider)
        } else {
            saveTrack(from: domain)
        }
    }

    func recordPlayed(_ track: TrackModel) {
        track.lastPlayedAt = Date()
        track.playCount += 1
        save()
        refresh()
    }

    // MARK: - Albums

    func saveAlbum(_ album: AlbumModel) {
        guard !savedAlbums.contains(where: { $0.id == album.id && $0.provider == album.provider }) else { return }
        context.insert(album)
        save()
        refresh()
    }

    func removeAlbum(_ album: AlbumModel) {
        context.delete(album)
        save()
        refresh()
    }

    func isAlbumSaved(id: String, provider: String) -> Bool {
        savedAlbums.contains { $0.id == id && $0.provider == provider }
    }

    // MARK: - Artists

    func saveArtist(_ artist: ArtistModel) {
        guard !savedArtists.contains(where: { $0.id == artist.id && $0.provider == artist.provider }) else { return }
        context.insert(artist)
        save()
        refresh()
    }

    func removeArtist(_ artist: ArtistModel) {
        context.delete(artist)
        save()
        refresh()
    }

    func isArtistSaved(id: String, provider: String) -> Bool {
        savedArtists.contains { $0.id == id && $0.provider == provider }
    }

    // MARK: - Playlists

    func savePlaylist(_ playlist: PlaylistModel) {
        context.insert(playlist)
        save()
        refresh()
    }

    func createPlaylist(name: String, description: String? = nil) -> PlaylistModel {
        let playlist = PlaylistModel(
            id: UUID().uuidString,
            name: name,
            playlistDescription: description,
            creator: "User",
            provider: "local",
            providerID: "",
            isEditable: true,
            createdAt: Date(),
            updatedAt: Date(),
            sortOrder: "manual"
        )
        savePlaylist(playlist)
        return playlist
    }

    func deletePlaylist(_ playlist: PlaylistModel) {
        context.delete(playlist)
        save()
        refresh()
    }

    func renamePlaylist(_ playlist: PlaylistModel, to name: String) {
        playlist.name = name
        playlist.updatedAt = Date()
        save()
        refresh()
    }

    func addTrackToPlaylist(_ playlist: PlaylistModel, track: TrackModel) {
        guard !playlist.trackIDs.contains(track.id) else { return }
        playlist.trackIDs.append(track.id)
        if !playlist.tracks.contains(where: { $0.id == track.id }) {
            playlist.tracks.append(track)
        }
        playlist.updatedAt = Date()
        save()
        refresh()
    }

    func removeTrackFromPlaylist(_ playlist: PlaylistModel, trackId: String) {
        playlist.trackIDs.removeAll { $0 == trackId }
        playlist.tracks.removeAll { $0.id == trackId }
        playlist.updatedAt = Date()
        save()
        refresh()
    }

    // MARK: - Persistence

    private func save() {
        do {
            try context.save()
        } catch {
            print("LibraryService save failed: \(error)")
        }
    }
}
