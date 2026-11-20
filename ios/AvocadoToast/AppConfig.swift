import Foundation

enum AppConfig {
    // Simulator: localhost. Physical iPhone: your Mac's LAN IP.
    static let apiBaseURL = URL(string: ProcessInfo.processInfo.environment["AVOCADO_API_URL"] ?? "http://127.0.0.1:8000")!
}