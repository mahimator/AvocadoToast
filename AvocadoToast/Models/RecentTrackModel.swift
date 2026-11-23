//
//  RecentTrackModel.swift
//  AvocadoToast
//
//  Lightweight listening history. Recent plays are not automatically saved
//  favorites, so they never pollute the user's saved-song library.
//

import Foundation
import SwiftData

@Model
final class RecentTrackModel {
    @Attribute(.unique) var id: String
    var provider: String
    var providerID: String
    var title: String
    var artistName: String
    var artworkURL: String?
    var duration: Double
    var lastPlayedAt: Date
    var playCount: Int

    init(id: String, provider: String, providerID: String, title: String, artistName: String,
         artworkURL: String? = nil, duration: Double = 0,
         lastPlayedAt: Date = Date(), playCount: Int = 1) {
        self.id = id
        self.provider = provider
        self.providerID = providerID
        self.title = title
        self.artistName = artistName
        self.artworkURL = artworkURL
        self.duration = duration
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
    }
}
