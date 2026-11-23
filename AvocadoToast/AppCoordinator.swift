//
//  AppCoordinator.swift
//  AvocadoToast
//

import SwiftUI
import Combine

enum NavigationDestination: Hashable {
    case home, search, library, albumDetail(String), artistDetail(String), playlistDetail(String), miniPlayer(String), nowPlaying, settings

    var id: String {
        switch self {
        case .home: return "home"
        case .search: return "search"
        case .library: return "library"
        case .albumDetail(let id): return "album_\(id)"
        case .artistDetail(let id): return "artist_\(id)"
        case .playlistDetail(let id): return "playlist_\(id)"
        case .miniPlayer(let id): return "miniplayer_\(id)"
        case .nowPlaying: return "nowplaying"
        case .settings: return "settings"
        }
    }
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var path: NavigationPath = NavigationPath()
    @Published var selection: NavigationDestination = .home
    @Published var searchQuery: String = ""
    @Published var isPlaying = false
    @Published var currentTrackID: String?
    @Published var playbackState: PlayerState = .idle
    @Published var showMiniPlayer = false
    @Published var showingNowPlaying = false
    init() {}
}

enum PlayerState: String {
    case idle, loading, ready, playing, paused, buffering, failed, ended
}
