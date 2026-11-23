//
//  HomeViewModel.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var tracks: [YouTubeTrack] = []
    @Published var greeting: String?
    @Published var isRefreshing: Bool = false

    private let catalogService: CatalogService

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    func onAppear() {
        updateGreeting()
        Task { await load() }
    }

    func onDisappear() {
        // No-op for now; home keeps its state
    }

    func refresh() async {
        isRefreshing = true
        await load()
        isRefreshing = false
    }

    private func load() async {
        await catalogService.fetchHomeTracks()
        self.tracks = catalogService.homeTracks
    }

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        case 17..<21: greeting = "Good evening"
        default: greeting = "Good night"
        }
    }
}
