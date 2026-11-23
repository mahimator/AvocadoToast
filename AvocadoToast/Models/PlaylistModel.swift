//
//  PlaylistModel.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import SwiftData

@Model
final class PlaylistModel {
    @Attribute(.unique) var id: String
    var name: String
    var playlistDescription: String?
    var artworkURL: String?
    var creator: String
    var provider: String
    var providerID: String
    var trackIDs: [String]
    var tracks: [TrackModel]
    var isEditable: Bool
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: String
    var metadata: [String: String]
    var providerIdentifiers: [String: String]

    init(id: String, name: String, playlistDescription: String? = nil, artworkURL: String? = nil,
         creator: String = "User", provider: String = "local", providerID: String = "",
         trackIDs: [String] = [], tracks: [TrackModel] = [], isEditable: Bool = true,
         createdAt: Date = Date(), updatedAt: Date = Date(), sortOrder: String = "manual",
         metadata: [String: String] = [:], providerIdentifiers: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.playlistDescription = playlistDescription
        self.artworkURL = artworkURL
        self.creator = creator
        self.provider = provider
        self.providerID = providerID
        self.trackIDs = trackIDs
        self.tracks = tracks
        self.isEditable = isEditable
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.metadata = metadata
        self.providerIdentifiers = providerIdentifiers
    }
}