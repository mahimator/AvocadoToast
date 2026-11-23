//
//  SearchService.swift
//  AvocadoToast
//
//  Owns persisted recent searches and search cancellation only.
//  SearchViewModel owns the debounce timer; CatalogService owns request/results.
//

import Foundation
import Combine

@MainActor
final class SearchService: ObservableObject {
    static let shared = SearchService()

    @Published var recentSearches: [String] = []

    private let catalogService: CatalogService

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    func cancelSearch() {
        catalogService.cancelSearch()
    }

    func addRecent(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 50 { recentSearches.removeLast() }
    }

    func clearHistory() {
        recentSearches.removeAll()
    }

    func removeRecent(_ query: String) {
        recentSearches.removeAll { $0 == query }
    }
}
