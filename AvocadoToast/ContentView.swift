//
//  ContentView.swift
//  AvocadoToast
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var catalogPlayer = AudioPlayerService.shared
    @ObservedObject private var config = AppConfig.shared

    private var preferredColorScheme: ColorScheme? {
        switch config.selectedAppearance {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $coordinator.selection) {
                HomeView()
                    .tabItem { Label("Listen", systemImage: "house.fill") }
                    .tag(NavigationDestination.home)
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(NavigationDestination.search)
                LibraryView()
                    .tabItem { Label("Library", systemImage: "square.stack.fill") }
                    .tag(NavigationDestination.library)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                    .tag(NavigationDestination.settings)
            }
            .environment(\.modelContext, modelContext)
            .tint(ColorTokens.accentPrimary)

            if catalogPlayer.currentTrack != nil {
                MiniPlayerView()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 72)
                    .transition(config.reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(config.reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: catalogPlayer.currentTrack != nil)
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $coordinator.showingNowPlaying) {
            NowPlayingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            syncCoordinatorPlaybackState()
        }
        .onChange(of: catalogPlayer.currentTrack?.videoId) { _, _ in
            syncCoordinatorPlaybackState()
        }
        .onChange(of: catalogPlayer.isPlaying) { _, _ in
            syncCoordinatorPlaybackState()
        }
    }

    private func syncCoordinatorPlaybackState() {
        coordinator.isPlaying = catalogPlayer.isPlaying
        coordinator.currentTrackID = catalogPlayer.currentTrack?.videoId
        coordinator.showMiniPlayer = catalogPlayer.currentTrack != nil
        coordinator.playbackState = catalogPlayer.currentTrack == nil ? .idle : (catalogPlayer.isPlaying ? .playing : .paused)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
        .modelContainer(for: [TrackModel.self, AlbumModel.self, ArtistModel.self, PlaylistModel.self, RecentTrackModel.self])
}
