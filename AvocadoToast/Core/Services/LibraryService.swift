//
//  LibraryService.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import Combine
import SwiftData
import SwiftyTube

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
    @Published private(set) var isSyncingYouTubeLibrary = false
    @Published var youtubeLibraryError: String?

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
        guard !exists else {
            DiagnosticLogger.shared.write("LIBRARY saveTrack skip exists id='\(track.id)' provider='\(track.provider)'")
            return
        }
        context.insert(track)
        save()
        refresh()
        DiagnosticLogger.shared.write("LIBRARY saveTrack saved id='\(track.id)' provider='\(track.provider)' title='\(track.title)'")
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
        DiagnosticLogger.shared.write("LIBRARY toggleSave id='\(track.videoId)' provider='\(track.provider)' title='\(track.title)' isSaved=\(isTrackSaved(id: track.videoId, provider: track.provider))")
        toggleSave(domain)
    }

    func toggleSave(_ domain: DomainTrack) {
        if isTrackSaved(id: domain.id, provider: domain.provider) {
            DiagnosticLogger.shared.write("LIBRARY toggleSave removing id='\(domain.id)' provider='\(domain.provider)'")
            removeTrack(by: domain.id, provider: domain.provider)
        } else {
            DiagnosticLogger.shared.write("LIBRARY toggleSave adding id='\(domain.id)' provider='\(domain.provider)'")
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

    // MARK: - Linked local music folder

    func importFolderScan(_ result: FolderScanResult) {
        refresh()
        var modelsByID = Dictionary(uniqueKeysWithValues: savedTracks.map { ($0.id, $0) })

        for item in result.files {
            if let existing = modelsByID[item.id] {
                existing.title = item.title
                existing.artistName = item.artist
                existing.duration = item.duration
                existing.artworkURL = item.artworkURL
                existing.providerID = item.fileURL.path
                existing.isPlayable = true
                existing.metadata["sourceRelativePath"] = item.relativePath
                existing.metadata["sourceFolderPath"] = item.relativeFolderPath
            } else {
                let model = TrackModel(
                    id: item.id,
                    provider: "local",
                    providerID: item.fileURL.path,
                    title: item.title,
                    artistName: item.artist,
                    artworkURL: item.artworkURL,
                    duration: item.duration,
                    isVideo: false,
                    isPlayable: true,
                    addedAt: Date(),
                    metadata: [
                        "sourceRelativePath": item.relativePath,
                        "sourceFolderPath": item.relativeFolderPath
                    ]
                )
                context.insert(model)
                modelsByID[item.id] = model
            }
        }

        for folder in result.playlists {
            let playlistID = "local-folder:" + folder.relativeFolderPath
            let members = folder.trackIDs.compactMap { modelsByID[$0] }
            if let existing = savedPlaylists.first(where: { $0.id == playlistID }) {
                existing.name = folder.name
                existing.trackIDs = folder.trackIDs
                existing.tracks = members
                existing.updatedAt = Date()
                existing.metadata["linkedFolder"] = result.folderName
                existing.metadata["relativeFolderPath"] = folder.relativeFolderPath
            } else {
                context.insert(PlaylistModel(
                    id: playlistID,
                    name: folder.name,
                    creator: "Your music folder",
                    provider: "local",
                    providerID: folder.relativeFolderPath,
                    trackIDs: folder.trackIDs,
                    tracks: members,
                    isEditable: true,
                    metadata: [
                        "source": "linked-folder",
                        "linkedFolder": result.folderName,
                        "relativeFolderPath": folder.relativeFolderPath
                    ]
                ))
            }
        }

        save()
        refresh()
        DiagnosticLogger.shared.write("LOCAL_FOLDER sync folder='\(result.folderName)' files=\(result.files.count) playlists=\(result.playlists.count)")
    }

    // MARK: - Remote YouTube Music library

    /// Imports the signed-in account's library into the local SwiftData cache.
    /// Existing local music and playlists are never removed by a remote refresh.
    func syncYouTubeLibrary() async {
        guard YouTubeAccountSession.shared.isSignedIn, !isSyncingYouTubeLibrary else { return }
        isSyncingYouTubeLibrary = true
        youtubeLibraryError = nil
        defer { isSyncingYouTubeLibrary = false }

        do {
            let snapshot = try await YouTubeKitService.shared.fetchLibrarySnapshot()

            for item in snapshot.tracks where !item.videoId.isEmpty {
                if let existing = savedTracks.first(where: { $0.provider == "youtube" && $0.providerID == item.videoId }) {
                    existing.title = item.title
                    existing.artistName = item.artist
                    existing.artworkURL = item.thumbnailURL
                    existing.duration = item.duration
                    existing.isPlayable = true
                } else {
                    context.insert(TrackModel(
                        id: item.videoId,
                        provider: "youtube",
                        providerID: item.videoId,
                        title: item.title,
                        artistName: item.artist,
                        artworkURL: item.thumbnailURL,
                        duration: item.duration,
                        isVideo: true,
                        isPlayable: true,
                        addedAt: Date()
                    ))
                }
            }

            for item in snapshot.albums where !item.browseId.isEmpty {
                if let existing = savedAlbums.first(where: { $0.provider == "youtube" && $0.providerID == item.browseId }) {
                    existing.title = item.title
                    existing.artistName = item.artist ?? "Unknown Artist"
                    existing.artworkURL = item.thumbnailUrl
                    existing.trackCount = item.songCount
                } else {
                    context.insert(AlbumModel(
                        id: "youtube|\(item.browseId)",
                        provider: "youtube",
                        providerID: item.browseId,
                        title: item.title,
                        artistName: item.artist ?? "Unknown Artist",
                        artworkURL: item.thumbnailUrl,
                        trackCount: item.songCount,
                        albumType: "album"
                    ))
                }
            }

            for item in snapshot.artists {
                guard let channelID = item.channelId, !channelID.isEmpty else { continue }
                if let existing = savedArtists.first(where: { $0.provider == "youtube" && $0.providerID == channelID }) {
                    existing.name = item.title
                    existing.artworkURL = item.thumbnailURL
                } else {
                    context.insert(ArtistModel(
                        id: "youtube|\(channelID)",
                        provider: "youtube",
                        providerID: channelID,
                        name: item.title,
                        artworkURL: item.thumbnailURL
                    ))
                }
            }

            for item in snapshot.playlists where !item.playlistId.isEmpty {
                let countText = item.videoCountText ?? "Playlist"
                if let existing = savedPlaylists.first(where: { $0.provider == "youtube" && $0.providerID == item.playlistId }) {
                    existing.name = item.title
                    existing.artworkURL = item.thumbnailURL
                    existing.metadata["trackCount"] = countText
                    existing.isEditable = false
                    existing.updatedAt = Date()
                } else {
                    context.insert(PlaylistModel(
                        id: "youtube|\(item.playlistId)",
                        name: item.title,
                        artworkURL: item.thumbnailURL,
                        creator: "YouTube Music",
                        provider: "youtube",
                        providerID: item.playlistId,
                        isEditable: false,
                        metadata: ["trackCount": countText]
                    ))
                }
            }

            save()
            refresh()
            DiagnosticLogger.shared.write("LIBRARY sync complete tracks=\(snapshot.tracks.count) playlists=\(snapshot.playlists.count) albums=\(snapshot.albums.count) artists=\(snapshot.artists.count)")
        } catch {
            youtubeLibraryError = error.localizedDescription
            DiagnosticLogger.shared.write("LIBRARY sync failed: \(error.localizedDescription)")
        }
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
