//
//  ArtistModel.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import SwiftData

@Model
final class ArtistModel {
    @Attribute(.unique) var id: String
    var provider: String
    var providerID: String
    var name: String
    var artworkURL: String?
    var artistDescription: String?
    var genres: [String]
    var albums: [AlbumModel]
    var singles: [AlbumModel]
    var topTracks: [TrackModel]
    var relatedArtists: [ArtistModel]
    var metadata: [String: String]
    var providerIdentifiers: [String: String]

    init(id: String, provider: String, providerID: String, name: String,
         artworkURL: String? = nil, artistDescription: String? = nil, genres: [String] = [],
         albums: [AlbumModel] = [], singles: [AlbumModel] = [], topTracks: [TrackModel] = [],
         relatedArtists: [ArtistModel] = [], metadata: [String: String] = [:],
         providerIdentifiers: [String: String] = [:]) {
        self.id = id
        self.provider = provider
        self.providerID = providerID
        self.name = name
        self.artworkURL = artworkURL
        self.artistDescription = artistDescription
        self.genres = genres
        self.albums = albums
        self.singles = singles
        self.topTracks = topTracks
        self.relatedArtists = relatedArtists
        self.metadata = metadata
        self.providerIdentifiers = providerIdentifiers
    }
}