//
//  ContentView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import SwiftData

/// Root shell of the application.
/// Wires together the AppCoordinator navigation, the three main tabs
/// (Home, Search, Library, Settings) and the persistent floating mini-player.
struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            NavigationStack(path: $coordinator.path) {
                TabView {
                    HomeView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(NavigationDestination.home)

                    SearchView()
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .tag(NavigationDestination.search)

                    LibraryView()
                        .tabItem {
                            Image(systemName: "music.note.list")
                            Text("Library")
                        }
                        .tag(NavigationDestination.library)

                    SettingsView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(NavigationDestination.settings)
                }
                .environment(\.modelContext, modelContext)
                .environmentObject(AppTheme.shared)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destinationView(destination)
                }
            }

            // Floating mini-player (shown when a track is selected)
            if PlayerService.shared.currentTrack != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                    .padding(.bottom, 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: PlayerService.shared.currentTrack != nil)
        .sheet(isPresented: $coordinator.showingNowPlaying) {
            NowPlayingView()
        }
        .onAppear {
            coordinator.isPlaying = PlayerService.shared.playbackState == .playing
            coordinator.currentTrackID = PlayerService.shared.currentTrack?.id
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: NavigationDestination) -> some View {
        switch destination {
        case .home:
            HomeView()
        case .search:
            SearchView()
        case .library:
            LibraryView()
        case .albumDetail(let id):
            AlbumDetailView(albumID: id)
        case .artistDetail(let id):
            ArtistDetailView(artistID: id)
        case .playlistDetail(let id):
            PlaylistDetailView(playlistID: id)
        case .miniPlayer:
            EmptyView()
        case .nowPlaying:
            NowPlayingView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        .modelContainer(for: [TrackModel.self, AlbumModel.self, ArtistModel.self, PlaylistModel.self])
}
