//
//  AppConfig.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import Combine

@MainActor
final class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    // Published state
    @Published var backendURL: URL {
        didSet { persistBackendURL() }
    }
    @Published var enableGlassEffects: Bool = true {
        didSet { persistGlassEffects() }
    }
    @Published var reduceMotion: Bool = false {
        didSet { persistReduceMotion() }
    }
    @Published var artworkBackgroundEnabled: Bool = true {
        didSet { persistArtworkBackground() }
    }
    
    // Cache TTL configuration (seconds)
    @Published var cacheTTLSearch: Double = 300
    @Published var cacheTTLTrack: Double = 86400
    @Published var cacheTTLAlbum: Double = 86400
    @Published var cacheTTLArtist: Double = 43200
    @Published var cacheTTLHome: Double = 900
    @Published var cacheTTLLyrics: Double = 86400
    
    // Provider configuration
    @Published var providerMaxConcurrency: Int = 5
    @Published var providerTimeout: Double = 15.0
    
    // Appearance
    @Published var selectedAppearance: Appearance = .dark {
        didSet { persistAppearance() }
    }
    
    enum Appearance: String, CaseIterable, Identifiable {
        case system = "System"
        case dark = "Dark"
        case light = "Light"
        var id: String { rawValue }
    }
    
    private enum Keys {
        static let backendURL = "backendURL"
        static let enableGlassEffects = "enableGlassEffects"
        static let reduceMotion = "reduceMotion"
        static let artworkBackgroundEnabled = "artworkBackgroundEnabled"
        static let selectedAppearance = "selectedAppearance"
    }
    
    private init() {
        let defaults = UserDefaults.standard
        if let savedURL = defaults.string(forKey: Keys.backendURL), let url = URL(string: savedURL) {
            self.backendURL = url
        } else {
            self.backendURL = URL(string: "http://localhost:8000")!
        }
        self.enableGlassEffects = defaults.object(forKey: Keys.enableGlassEffects) as? Bool ?? true
        self.reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        self.artworkBackgroundEnabled = defaults.object(forKey: Keys.artworkBackgroundEnabled) as? Bool ?? true
        if let savedAppearance = defaults.string(forKey: Keys.selectedAppearance),
           let appearance = Appearance(rawValue: savedAppearance) {
            self.selectedAppearance = appearance
        }
    }
    
    private func persistBackendURL() {
        UserDefaults.standard.setValue(backendURL.absoluteString, forKey: Keys.backendURL)
    }
    
    private func persistGlassEffects() {
        UserDefaults.standard.setValue(enableGlassEffects, forKey: Keys.enableGlassEffects)
    }
    
    private func persistReduceMotion() {
        UserDefaults.standard.setValue(reduceMotion, forKey: Keys.reduceMotion)
    }
    
    private func persistArtworkBackground() {
        UserDefaults.standard.setValue(artworkBackgroundEnabled, forKey: Keys.artworkBackgroundEnabled)
    }

    private func persistAppearance() {
        UserDefaults.standard.setValue(selectedAppearance.rawValue, forKey: Keys.selectedAppearance)
    }
}