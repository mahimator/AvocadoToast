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
    private var activeLoadID: UUID?

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
        let requestID = UUID()
        activeLoadID = requestID
        isLoading = true
        await catalogService.fetchHomeTracks()
        guard activeLoadID == requestID else { return }
        tracks = catalogService.homeTracks
        isLoading = false
        activeLoadID = nil
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
