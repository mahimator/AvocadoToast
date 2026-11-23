//
//  HomeViewModel.swift
//  AvocadoToast
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var tracks: [YouTubeTrack] = []
    @Published private(set) var greeting: String?
    @Published private(set) var isLoading = false
    @Published var isRefreshing = false

    private let catalogService: CatalogService
    private var hasLoaded = false

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
        updateGreeting()
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await load()
    }

    func refresh() async {
        isRefreshing = true
        await load()
        hasLoaded = true
        isRefreshing = false
    }

    private func load() async {
        isLoading = true
        await catalogService.fetchHomeTracks()
        tracks = catalogService.homeTracks
        isLoading = false
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
