//
//  AlbumModel.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import SwiftData

@Model
final class AlbumModel {
    @Attribute(.unique) var id: String
    var provider: String
    var providerID: String
    var title: String
    var artistName: String
    var artistIDs: [String]
    var artworkURL: String?
    var releaseDate: String?
    var trackCount: Int
    var albumType: String
    var tracks: [TrackModel]
    var metadata: [String: String]
    var providerIdentifiers: [String: String]

    init(id: String, provider: String, providerID: String, title: String, artistName: String,
         artistIDs: [String] = [], artworkURL: String? = nil, releaseDate: String? = nil,
         trackCount: Int = 0, albumType: String = "album", tracks: [TrackModel] = [],
         metadata: [String: String] = [:], providerIdentifiers: [String: String] = [:]) {
        self.id = id
        self.provider = provider
        self.providerID = providerID
        self.title = title
        self.artistName = artistName
        self.artistIDs = artistIDs
        self.artworkURL = artworkURL
        self.releaseDate = releaseDate
        self.trackCount = trackCount
        self.albumType = albumType
        self.tracks = tracks
        self.metadata = metadata
        self.providerIdentifiers = providerIdentifiers
    }
}