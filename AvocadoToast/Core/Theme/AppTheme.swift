//
//  AppTheme.swift
//  AvocadoToast
//

import SwiftUI
import Combine

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
}

extension AppTheme: EnvironmentKey {
    public static let defaultValue: AppTheme = AppTheme()
}

@MainActor
final class AppTheme: ObservableObject {
    static let shared = AppTheme()

    @Published var colorScheme: AppColorScheme = .system
    @Published var reduceMotion: Bool = false

    private let espresso = Color(red: 23/255, green: 22/255, blue: 18/255)
    private let warmPaper = Color(red: 239/255, green: 232/255, blue: 216/255)
    private let olive = Color(red: 174/255, green: 183/255, blue: 124/255)
    private let ivory = Color(red: 244/255, green: 237/255, blue: 220/255)
    private let warmInk = Color(red: 57/255, green: 52/255, blue: 43/255)

    var resolvedBackgroundPrimary: Color {
        switch colorScheme {
        case .light: warmPaper
        case .dark: espresso
        case .system: Color(.systemBackground)
        }
    }
    var resolvedTextPrimary: Color {
        switch colorScheme {
        case .light: warmInk
        case .dark: ivory
        case .system: Color(.label)
        }
    }
    var resolvedTextSecondary: Color {
        switch colorScheme {
        case .light: warmInk.opacity(0.62)
        case .dark: ivory.opacity(0.62)
        case .system: Color(.secondaryLabel)
        }
    }
    var resolvedSurfaceGlass: Color { ivory.opacity(colorScheme == .light ? 0.22 : 0.08) }
    var resolvedSurfaceElevated: Color { ivory.opacity(colorScheme == .light ? 0.38 : 0.12) }
    var resolvedAccentPrimary: Color { olive }
    var resolvedSeparator: Color { ivory.opacity(colorScheme == .light ? 0.18 : 0.1) }
    var resolvedPlayerProgress: Color { Color(red: 224/255, green: 196/255, blue: 142/255) }

    var glassOpacity: Double { reduceMotion ? 0.3 : 0.08 }
    var cornerRadius: CGFloat { reduceMotion ? 8 : 16 }
}
