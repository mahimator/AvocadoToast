//
//  SearchService.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import Combine

/// Search service: debounces typing, tracks recent searches, and owns search
/// query state so duplicate network requests from uncontrolled typing are avoided.
@MainActor
final class SearchService: ObservableObject {
    static let shared = SearchService()

    @Published var recentSearches: [String] = []
    @Published var isSearching: Bool = false

    private let catalogService: CatalogService
    private var debounceTask: Task<Void, Never>?

    init(catalogService: CatalogService = .shared) {
        self.catalogService = catalogService
    }

    /// Debounced search. Only the latest query within `delay` seconds is sent.
    func debounceSearch(_ query: String, delay: Double = 0.4) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            addRecent(trimmed)
            catalogService.search(query: trimmed)
        }
    }

    func cancelSearch() {
        debounceTask?.cancel()
        debounceTask = nil
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
