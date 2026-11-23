//
//  AppTheme.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
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

    var resolvedBackgroundPrimary: Color {
        switch colorScheme { case .light: return Color(red: 240/255, green: 240/255, blue: 245/255); case .dark: return Color(red: 10/255, green: 10/255, blue: 15/255); case .system: return Color(.systemBackground) }
    }
    var resolvedTextPrimary: Color { colorScheme == .light ? Color(red: 10/255, green: 10/255, blue: 15/255) : .white }
    var resolvedTextSecondary: Color { colorScheme == .light ? Color(red: 80/255, green: 80/255, blue: 90/255) : Color.white.opacity(0.6) }
    var resolvedSurfaceGlass: Color { Color.white.opacity(0.08) }
    var resolvedSurfaceElevated: Color { Color.white.opacity(0.12) }
    var resolvedAccentPrimary: Color { Color(red: 239/255, green: 139/255, blue: 87/255) }
    var resolvedSeparator: Color { Color.white.opacity(0.1) }
    var resolvedPlayerProgress: Color { Color(red: 239/255, green: 139/255, blue: 87/255) }
    
    var glassOpacity: Double { reduceMotion ? 0.3 : 0.08 }
    var cornerRadius: CGFloat { reduceMotion ? 8 : 16 }
}