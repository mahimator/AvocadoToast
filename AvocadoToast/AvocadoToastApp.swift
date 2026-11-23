//
//  AvocadoToastApp.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import SwiftData

@main
struct AvocadoToastApp: App {
    @StateObject private var config = AppConfig.shared

    private var preferredScheme: ColorScheme? {
        switch config.selectedAppearance {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppCoordinator())
                 .modelContainer(for: [TrackModel.self, AlbumModel.self, ArtistModel.self, PlaylistModel.self])
                .preferredColorScheme(preferredScheme)
        }
    }
}
