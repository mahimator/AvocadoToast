//
//  PersistenceController.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftData
import Foundation

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()
    let container: ModelContainer
    
    private init() {
        let schema = Schema([TrackModel.self, AlbumModel.self, ArtistModel.self, PlaylistModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do { container = try ModelContainer(for: schema, configurations: [config]) }
        catch { fatalError("Failed PersistenceController: \(error)") }
    }
    
    var context: ModelContext { container.mainContext }
}