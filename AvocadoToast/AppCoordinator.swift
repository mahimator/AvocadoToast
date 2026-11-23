//
//  AppCoordinator.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import Combine

// Simplified track model for coordinator use
struct CoordinatorTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: String?
    let isPlaying: Bool
    let isPlayable: Bool
    
    static func == (lhs: CoordinatorTrack, rhs: CoordinatorTrack) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Simplified navigation destination
enum NavigationDestination: Hashable {
    case home
    case search
    case library
    case albumDetail(String)
    case artistDetail(String)
    case playlistDetail(String)
    case miniPlayer(String) // trackID
    case nowPlaying
    case settings
    
    var id: String {
        switch self {
        case .home: return "home"
        case .search: return "search"
        case .library: return "library"
        case .albumDetail(let id): return "album_\(id)"
        case .artistDetail(let id): return "artist_\(id)"
        case .playlistDetail(let id): return "playlist_\(id)"
        case .miniPlayer(let trackID): return "miniplayer_\(trackID)"
        case .nowPlaying: return "nowplaying"
        case .settings: return "settings"
        }
    }
}

// Operator overload for NavigationDestination equality
func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
    lhs.id == rhs.id
}

// Player state enum
enum PlayerState: String {
    case idle = "Idle"
    case loading = "Loading"
    case ready = "Ready"
    case playing = "Playing"
    case paused = "Paused"
    case buffering = "Buffering"
    case failed = "Failed"
    case ended = "Ended"
}

// App Coordinator
@MainActor
final class AppCoordinator: ObservableObject {
    // Published navigation state
    @Published var path: NavigationPath = NavigationPath()
    @Published var selection: NavigationDestination?
    
    // Published app state
    @Published var isPlaying: Bool = false
    @Published var currentTrackID: String?
    @Published var playbackState: PlayerState = .idle
    @Published var showMiniPlayer: Bool = false
    @Published var showingNowPlaying: Bool = false

    // Initialize coordinator
    init() {}
}