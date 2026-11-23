//
//  APIModels.swift
//  AvocadoToast
//
//  Shared catalog response types retained for home sections and provider data.
//

import Foundation

struct SearchResponse: Codable {
    let query: String
    let category: String
    let results: [SearchResult]
    let nextPage: String?
}

struct SearchResult: Identifiable, Codable {
    let id: String
    let provider: String
    let type: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: String?
    let durationSeconds: Double?
    let explicit: Bool?
    let playable: Bool
    let metadata: [String: String]?
    let providerIdentifiers: [String: String]?
}

struct MusicEntity: Codable {
    let id: String
    let provider: String
    let entityType: String
    let title: String
    let subtitle: String
    let artwork: String?
    let metadata: [String: String]?
    let providerIdentifiers: [String: String]?
}

struct TrackResponse: Codable {
    let id: String
    let provider: String
    let providerID: String
    let title: String
    let artistName: String
    let artistIDs: [String]
    let albumName: String?
    let albumID: String?
    let artworkURL: String?
    let duration: Double?
    let explicit: Bool?
    let isVideo: Bool
    let isPlayable: Bool
    let metadata: [String: String]?
    let providerIdentifiers: [String: String]?
}

struct AlbumResponse: Codable {
    let id: String
    let provider: String
    let providerID: String
    let title: String
    let artist: String
    let artistIDs: [String]
    let artworkURL: String?
    let releaseDate: String?
    let trackCount: Int
    let albumType: String
    let tracks: [TrackResponse]
    let metadata: [String: String]?
    let providerIdentifiers: [String: String]?
}

struct ArtistResponse: Codable {
    let id: String
    let provider: String
    let providerID: String
    let name: String
    let artworkURL: String?
    let description: String?
    let genres: [String]
    let albums: [AlbumResponse]
    let singles: [AlbumResponse]
    let topTracks: [TrackResponse]
    let relatedArtists: [ArtistResponse]
    let metadata: [String: String]?
    let providerIdentifiers: [String: String]?
}

struct PlaylistResponse: Codable {
    let id: String
    let provider: String
    let providerID: String
    let title: String
    let description: String?
    let artworkURL: String?
    let creator: String
    let trackCount: Int
    let tracks: [TrackResponse]
    let isEditable: Bool
    let metadata: [String: String]?
    let providerIdentifiers: [String: String]?
}

struct HomeResponse: Codable {
    let sections: [HomeSection]
}

struct HomeSection: Codable, Identifiable {
    let id: String
    let title: String
    let type: String
    let items: [MusicEntity]
}

struct LyricsResponse: Codable {
    let trackID: String
    let lyrics: String?
    let hasLyrics: Bool
}

struct HealthResponse: Codable {
    let status: String
    let provider: String
    let version: String
}

struct ChartsResponse: Codable {
    let charts: [ChartCategory]
}

struct ChartCategory: Codable, Identifiable {
    let id: String
    let title: String
    let items: [MusicEntity]
}

struct APIErrorResponse: Codable {
    let error: String
    let detail: String?
}
