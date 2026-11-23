//
//  LibraryServiceTests.swift
//  AvocadoToastTests
//
//  Phase 3 · Local library · Persistence → Imports → Deletion
//  (Playlists, saved tracks/albums/artists, deletion, reset, in-memory persistence)
//

import Foundation
import SwiftData
import XCTest

@MainActor
final class LibraryServiceTests: XCTestCase {
    private func makeContext() -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: TrackModel.self, AlbumModel.self, ArtistModel.self, PlaylistModel.self, RecentTrackModel.self,
            configurations: [config]
        )
        return container.mainContext
    }

    private func makeTrack(id: String = "track-\(UUID())", provider: String = "youtube") -> TrackModel {
        TrackModel(
            id: id,
            provider: provider,
            providerID: "provider-\(id)",
            title: "Test Song",
            artistName: "Test Artist",
            albumName: "Test Album",
            artworkURL: nil,
            duration: 180,
            explicit: false,
            isVideo: false,
            isPlayable: true,
            addedAt: Date(),
            playCount: 0
        )
    }

    private func makeService() -> LibraryService {
        LibraryService(context: makeContext())
    }

    func testSaveAndRemoveTrack() {
        let service = makeService()
        let track = makeTrack()
        service.saveTrack(track)
        XCTAssertTrue(service.isTrackSaved(id: track.id, provider: track.provider))
        XCTAssertEqual(service.savedTracks.count, 1)

        service.removeTrack(track)
        XCTAssertFalse(service.isTrackSaved(id: track.id, provider: track.provider))
        XCTAssertEqual(service.savedTracks.count, 0)
    }

    func testSaveTrackIsIdempotent() {
        let service = makeService()
        let track = makeTrack()
        service.saveTrack(track)
        service.saveTrack(track)
        XCTAssertEqual(service.savedTracks.count, 1)
    }

    func testSaveAndRemoveAlbum() {
        let service = makeService()
        let album = AlbumModel(
            id: "album-1", provider: "youtube", providerID: "p-1", title: "Test Album", artist: "Test Artist",
            artistIDs: [], artworkURL: nil, releaseDate: nil, trackCount: 5, albumType: "album",
            tracks: [], metadata: [:], providerIdentifiers: [:]
        )
        service.saveAlbum(album)
        XCTAssertTrue(service.isAlbumSaved(id: album.id, provider: album.provider))
        service.removeAlbum(album)
        XCTAssertFalse(service.isAlbumSaved(id: album.id, provider: album.provider))
    }

    func testSaveAndRemoveArtist() {
        let service = makeService()
        let artist = ArtistModel(
            id: "artist-1", provider: "youtube", providerID: "p-1", name: "Test Artist", artworkURL: nil,
            description: nil, genres: [], albums: [], singles: [], topTracks: [], relatedArtists: [],
            metadata: [:], providerIdentifiers: [:]
        )
        service.saveArtist(artist)
        XCTAssertTrue(service.isArtistSaved(id: artist.id, provider: artist.provider))
        service.removeArtist(artist)
        XCTAssertFalse(service.isArtistSaved(id: artist.id, provider: artist.provider))
    }

    func testCreatePlaylist() {
        let service = makeService()
        let playlist = service.createPlaylist(name: "Chill", description: "A little playlist")
        XCTAssertEqual(playlist.name, "Chill")
        XCTAssertEqual(playlist.playlistDescription, "A little playlist")
        XCTAssertEqual(service.savedPlaylists.count, 1)
        XCTAssertTrue(playlist.isEditable)
    }

    func testRenamePlaylist() {
        let service = makeService()
        let playlist = service.createPlaylist(name: "Old")
        service.renamePlaylist(playlist, to: "New")
        XCTAssertEqual(service.savedPlaylists.first?.name, "New")
    }

    func testDeletePlaylist() {
        let service = makeService()
        let playlist = service.createPlaylist(name: "To Delete")
        service.deletePlaylist(playlist)
        XCTAssertEqual(service.savedPlaylists.count, 0)
    }

    func testAddAndRemoveTrackFromPlaylist() {
        let service = makeService()
        let playlist = service.createPlaylist(name: "List")
        let track = makeTrack()
        service.saveTrack(track)

        service.addTrackToPlaylist(playlist, track: track)
        XCTAssertTrue(playlist.trackIDs.contains(track.id))
        XCTAssertEqual(playlist.tracks.count, 1)

        // Adding again is a no-op.
        service.addTrackToPlaylist(playlist, track: track)
        XCTAssertEqual(playlist.trackIDs.filter { $0 == track.id }.count, 1)

        service.removeTrackFromPlaylist(playlist, trackId: track.id)
        XCTAssertFalse(playlist.trackIDs.contains(track.id))
        XCTAssertEqual(playlist.tracks.count, 0)
    }

    func testReorderPlaylist() {
        let service = makeService()
        let playlist = service.createPlaylist(name: "Ordered")
        let t1 = makeTrack(id: "a"); let t2 = makeTrack(id: "b"); let t3 = makeTrack(id: "c")
        [t1, t2, t3].forEach { service.saveTrack($0) }
        service.addTrackToPlaylist(playlist, track: t1)
        service.addTrackToPlaylist(playlist, track: t2)
        service.addTrackToPlaylist(playlist, track: t3)
        XCTAssertEqual(playlist.trackIDs, ["a", "b", "c"])

        service.moveTrackInPlaylist(playlist, from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(playlist.trackIDs, ["b", "c", "a"])
    }

    func testResetLibrary() {
        let context = makeContext()
        let service = LibraryService(context: context)
        let track = makeTrack(provider: "youtube")
        service.saveTrack(track)
        let playlist = service.createPlaylist(name: "List")
        service.addTrackToPlaylist(playlist, track: track)
        XCTAssertGreaterThan(service.savedTracks.count, 0)
        XCTAssertGreaterThan(service.savedPlaylists.count, 0)

        // Reset: delete every persisted object.
        for item in try! context.fetch(FetchDescriptor<TrackModel>()) { context.delete(item) }
        for item in try! context.fetch(FetchDescriptor<AlbumModel>()) { context.delete(item) }
        for item in try! context.fetch(FetchDescriptor<ArtistModel>()) { context.delete(item) }
        for item in try! context.fetch(FetchDescriptor<PlaylistModel>()) { context.delete(item) }
        for item in try! context.fetch(FetchDescriptor<RecentTrackModel>()) { context.delete(item) }
        try! context.save()
        service.refresh()
        XCTAssertEqual(service.savedTracks.count, 0)
        XCTAssertEqual(service.savedPlaylists.count, 0)
    }

    func testPersistenceSurvivesContextRefresh() {
        let context = makeContext()
        let service = LibraryService(context: context)
        let track = makeTrack()
        service.saveTrack(track)

        // A fresh service backed by the same in-memory context sees the saved track.
        let service2 = LibraryService(context: context)
        XCTAssertTrue(service2.isTrackSaved(id: track.id, provider: track.provider))
    }
}
