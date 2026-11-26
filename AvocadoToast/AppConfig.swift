//
//  AppConfig.swift
//  AvocadoToast
//
//  User-facing preferences only. Provider/network configuration belongs to the
//  catalog service, not a settings object that the UI never exposes.
//

import Foundation
import Combine

@MainActor
final class AppConfig: ObservableObject {
    static let shared = AppConfig()

    @Published var enableGlassEffects: Bool = true {
        didSet { UserDefaults.standard.set(enableGlassEffects, forKey: Keys.enableGlassEffects) }
    }
    @Published var reduceMotion: Bool = false {
        didSet { UserDefaults.standard.set(reduceMotion, forKey: Keys.reduceMotion) }
    }
    @Published var artworkBackgroundEnabled: Bool = true {
        didSet { UserDefaults.standard.set(artworkBackgroundEnabled, forKey: Keys.artworkBackgroundEnabled) }
    }
    @Published var selectedAppearance: Appearance = .dark {
        didSet { UserDefaults.standard.set(selectedAppearance.rawValue, forKey: Keys.selectedAppearance) }
    }
    @Published var searchMediaMode: SearchMediaMode = .audio {
        didSet { UserDefaults.standard.set(searchMediaMode.rawValue, forKey: Keys.searchMediaMode) }
    }

    enum SearchMediaMode: String, CaseIterable, Identifiable {
        case audio = "Audio"
        case video = "Video"
        var id: String { rawValue }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system = "System"
        case dark = "Dark"
        case light = "Light"
        var id: String { rawValue }
    }

    private enum Keys {
        static let enableGlassEffects = "enableGlassEffects"
        static let reduceMotion = "reduceMotion"
        static let artworkBackgroundEnabled = "artworkBackgroundEnabled"
        static let selectedAppearance = "selectedAppearance"
        static let searchMediaMode = "AvocadoToast.searchMediaMode"
    }

    private init() {
        let defaults = UserDefaults.standard
        enableGlassEffects = defaults.object(forKey: Keys.enableGlassEffects) as? Bool ?? true
        reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        artworkBackgroundEnabled = defaults.object(forKey: Keys.artworkBackgroundEnabled) as? Bool ?? true
        if let savedAppearance = defaults.string(forKey: Keys.selectedAppearance),
           let appearance = Appearance(rawValue: savedAppearance) {
            selectedAppearance = appearance
        }
        if let savedMode = defaults.string(forKey: Keys.searchMediaMode),
           let mode = SearchMediaMode(rawValue: savedMode) {
            searchMediaMode = mode
        }
    }
}
