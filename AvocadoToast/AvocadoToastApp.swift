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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppCoordinator())
                .modelContainer(for: [TrackModel.self, AlbumModel.self, ArtistModel.self, PlaylistModel.self])
        }
    }
}
