//
//  APIClient.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import Combine
import UIKit

@MainActor
final class APIClient: ObservableObject {
    // Singleton instance
    static let shared = APIClient()
    
    // Published state
    @Published var isFetching: Bool = false
    @Published var lastError: APIError?
    
    // Backend configuration
    private let baseURL: URL
    private let session: URLSession
    
    private init() {
        let config = AppConfig.shared
        guard let url = URL(string: config.backendURL.absoluteString) else {
            fatalError("Invalid backend URL configuration")
        }
        self.baseURL = url
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        isFetching = true
        lastError = nil
        
        defer { isFetching = false }
        
        var request = endpoint.urlRequest(baseURL: baseURL)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299: break
            case 400...499: throw APIError.clientError(statusCode: httpResponse.statusCode)
            case 500...599: throw APIError.serverError(statusCode: httpResponse.statusCode)
            default: throw APIError.unknownStatusCode(statusCode: httpResponse.statusCode)
            }
            
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error)
        }
    }
    
    func upload<T: Encodable>(_ data: T, to endpoint: APIEndpoint) async throws where T: Encodable {
        var request = endpoint.urlRequest(baseURL: baseURL)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(data)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
    
    func cancelAllRequests() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
}

// API Endpoint enum
enum APIEndpoint {
    case health
    case search(query: String, type: SearchType?, limit: Int?)
    case home
    case song(id: String)
    case album(id: String)
    case artist(id: String)
    case playlist(id: String)
    case related(id: String)
    case lyrics(id: String)
    case charts
    
    func urlRequest(baseURL: URL) -> URLRequest {
        var request: URLRequest
        switch self {
        case .health: request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/health"))
        case .search(let query, let type, let limit):
            request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/search"))
            request.httpMethod = "GET"
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            var queryItems: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
            if let type = type { queryItems.append(URLQueryItem(name: "type", value: type.rawValue)) }
            if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
            components.queryItems = queryItems
            request.url = components.url
        case .home: request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/home"))
        case .song(let id): request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/songs/\(id)"))
        case .album(let id): request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/albums/\(id)"))
        case .artist(let id): request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/artists/\(id)"))
        case .playlist(let id): request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/playlists/\(id)"))
        case .related(let id): request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/songs/\(id)/related"))
        case .lyrics(let id): request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/songs/\(id)/lyrics"))
        case .charts: request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/charts"))
        }
        return request
    }
}

// API Error enum
enum APIError: LocalizedError {
    case invalidResponse
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
    case unknownStatusCode(statusCode: Int)
    case network(Error)
    case decoding(Error)
    case emptyResponse
    case providerUnavailable
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .clientError(let statusCode): return "Bad request (\(statusCode))"
        case .serverError(let statusCode): return "Server error (\(statusCode))"
        case .unknownStatusCode(let statusCode): return "Unknown status code: \(statusCode)"
        case .network(let error): return "Network error: \(error.localizedDescription)"
        case .decoding(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .emptyResponse: return "Empty response from server"
        case .providerUnavailable: return "Music catalog is temporarily unavailable"
        case .timeout: return "Request timed out"
        }
    }
}

// SearchType enum - defined once project-wide
enum SearchType: String, CaseIterable {
    case songs = "songs"
    case videos = "videos"
    case albums = "albums"
    case artists = "artists"
    case playlists = "playlists"
    case all = "all"
}