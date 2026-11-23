//
//  LocalTrackModel.swift
//  AvocadoToast
//
//  A track stored locally on the device. Fully independent of any backend.
//

import Foundation
import SwiftData

@Model
final class LocalTrackModel: @unchecked Sendable {
    @Attribute(.unique) var id: String
    var title: String
    var artist: String
    var album: String?
    var artworkURL: String?
    var previewURL: String?      // iTunes 30-second preview URL
    var localFileURL: String?    // file:// path after download
    var duration: Double?        // seconds
    var genre: String?
    var trackNumber: Int
    var isDownloaded: Bool
    var downloadedAt: Date?
    var playCount: Int
    var lastPlayedAt: Date?

    init(id: String, title: String, artist: String, album: String? = nil,
         artworkURL: String? = nil, previewURL: String? = nil,
         localFileURL: String? = nil, duration: Double? = nil,
         genre: String? = nil, trackNumber: Int = 0,
         isDownloaded: Bool = false, downloadedAt: Date? = nil,
         playCount: Int = 0, lastPlayedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.previewURL = previewURL
        self.localFileURL = localFileURL
        self.duration = duration
        self.genre = genre
        self.trackNumber = trackNumber
        self.isDownloaded = isDownloaded
        self.downloadedAt = downloadedAt
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
    }
}

@Model
final class LocalPlaylistModel: @unchecked Sendable {
    @Attribute(.unique) var id: String
    var name: String
    var playlistDescription: String?
    var artworkURL: String?
    var trackIDs: [String]
    var isEditable: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, name: String, playlistDescription: String? = nil,
         artworkURL: String? = nil, trackIDs: [String] = [], isEditable: Bool = true,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.playlistDescription = playlistDescription
        self.artworkURL = artworkURL
        self.trackIDs = trackIDs
        self.isEditable = isEditable
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
