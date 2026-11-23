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
    @Published private(set) var recentlyPlayed: [RecentTrackModel] = []

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
            recentlyPlayed = try context.fetch(FetchDescriptor<RecentTrackModel>(
                sortBy: [SortDescriptor(\RecentTrackModel.lastPlayedAt, order: .reverse)]
            ))
        } catch {
            print("LibraryService refresh failed: \(error)")
        }
    }

    // MARK: - Tracks

    func saveTrack(_ track: TrackModel) {
        // TrackModel.id is globally unique in SwiftData, so prevent collisions
        // across providers as well as duplicate saves within one provider.
        let exists = savedTracks.contains { $0.id == track.id }
        guard !exists else { return }
        context.insert(track)
        save()
        refresh()
    }

    func saveTracks(_ tracks: [TrackModel]) {
        guard !tracks.isEmpty else { return }
        // TrackModel.id has a global unique constraint, not a provider-scoped one.
        let existingIDs = Set(savedTracks.map(\.id))
        var insertedIDs = Set<String>()
        for track in tracks {
            guard !existingIDs.contains(track.id), insertedIDs.insert(track.id).inserted else { continue }
            context.insert(track)
        }
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
        if track.provider == "local" {
            LocalAudioManager.shared.deleteImportedAudio(at: track.providerID)
        }
        // Keep playlist membership consistent with the library deletion.
        for playlist in savedPlaylists {
            let hasExactRelationship = playlist.tracks.contains { $0.id == track.id && $0.provider == track.provider }
            let hasProviderConflict = playlist.tracks.contains { $0.id == track.id && $0.provider != track.provider }
            if hasExactRelationship || !hasProviderConflict {
                playlist.trackIDs.removeAll { $0 == track.id }
            }
            playlist.tracks.removeAll { $0.id == track.id && $0.provider == track.provider }
        }
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

    func toggleSaveYouTubeTrack(_ track: YouTubeTrack) {
        let domain = DomainTrack(
            id: track.videoId,
            provider: track.provider,
            providerID: track.provider == "local" ? (track.localFileURL ?? track.videoId) : track.videoId,
            title: track.title,
            artistName: track.artist,
            artworkURL: track.thumbnailURL.flatMap { URL(string: $0) },
            duration: track.duration,
            isVideo: track.provider != "local",
            isPlayable: true
        )
        toggleSave(domain)
    }

    func toggleSave(_ domain: DomainTrack) {
        if isTrackSaved(id: domain.id, provider: domain.provider) {
            removeTrack(by: domain.id, provider: domain.provider)
        } else {
            saveTrack(from: domain)
        }
    }

    func recordPlayed(_ track: YouTubeTrack) {
        let provider = track.provider
        let stableID = "\(provider)|\(track.videoId)"
        let now = Date()
        if let existing = recentlyPlayed.first(where: { $0.id == stableID }) {
            existing.lastPlayedAt = now
            existing.playCount += 1
            existing.providerID = track.provider == "local" ? (track.localFileURL ?? track.videoId) : track.videoId
            existing.title = track.title
            existing.artistName = track.artist
            existing.artworkURL = track.thumbnailURL
            existing.duration = track.duration
        } else {
            context.insert(RecentTrackModel(
                id: stableID,
                provider: provider,
                providerID: track.provider == "local" ? (track.localFileURL ?? track.videoId) : track.videoId,
                title: track.title,
                artistName: track.artist,
                artworkURL: track.thumbnailURL,
                duration: track.duration,
                lastPlayedAt: now
            ))
        }
        save()
        refresh()
        // Keep history bounded to the most recent 100 unique tracks.
        if recentlyPlayed.count > 100 {
            for stale in recentlyPlayed.dropFirst(100) { context.delete(stale) }
            save()
            refresh()
        }
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
        guard !savedPlaylists.contains(where: { $0.id == playlist.id && $0.provider == playlist.provider }) else { return }
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

    func moveTrackInPlaylist(_ playlist: PlaylistModel, from offsets: IndexSet, to destination: Int) {
        guard !offsets.isEmpty, destination >= 0, destination <= playlist.trackIDs.count else { return }
        var ids = playlist.trackIDs
        let moving = offsets.sorted().map { ids[$0] }
        for index in offsets.sorted(by: >) { ids.remove(at: index) }
        let adjustedDestination = max(0, min(ids.count, destination - offsets.filter { $0 < destination }.count))
        ids.insert(contentsOf: moving, at: adjustedDestination)
        playlist.trackIDs = ids
        playlist.tracks = ids.compactMap { id in savedTracks.first(where: { $0.id == id }) }
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
