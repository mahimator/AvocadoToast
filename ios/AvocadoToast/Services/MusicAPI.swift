import Foundation

protocol MusicCatalog {
    func searchTracks(query: String) async throws -> [Track]
}

struct MusicAPI: MusicCatalog {
    let baseURL: URL

    func searchTracks(query: String) async throws -> [Track] {
        var components = URLComponents(url: baseURL.appendingPathComponent("v1/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Track].self, from: data)
    }
}