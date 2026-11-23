//
//  TrackModel.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import SwiftData

@Model
final class TrackModel {
    @Attribute(.unique) var id: String
    var provider: String
    var providerID: String
    var title: String
    var artistName: String
    var artistIDs: [String]
    var albumName: String?
    var albumID: String?
    var artworkURL: String?
    var duration: Double?
    var explicit: Bool?
    var isVideo: Bool
    var isPlayable: Bool
    var addedAt: Date?
    var lastPlayedAt: Date?
    var playCount: Int
    var metadata: [String: String]
    var providerIdentifiers: [String: String]

    init(id: String, provider: String, providerID: String, title: String, artistName: String,
         artistIDs: [String] = [], albumName: String? = nil, albumID: String? = nil,
         artworkURL: String? = nil, duration: Double? = nil, explicit: Bool? = nil,
         isVideo: Bool = false, isPlayable: Bool = true, addedAt: Date? = nil,
         lastPlayedAt: Date? = nil, playCount: Int = 0,
         metadata: [String: String] = [:], providerIdentifiers: [String: String] = [:]) {
        self.id = id
        self.provider = provider
        self.providerID = providerID
        self.title = title
        self.artistName = artistName
        self.artistIDs = artistIDs
        self.albumName = albumName
        self.albumID = albumID
        self.artworkURL = artworkURL
        self.duration = duration
        self.explicit = explicit
        self.isVideo = isVideo
        self.isPlayable = isPlayable
        self.addedAt = addedAt
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
        self.metadata = metadata
        self.providerIdentifiers = providerIdentifiers
    }
}