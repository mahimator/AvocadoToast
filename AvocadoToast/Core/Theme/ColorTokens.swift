//
//  ColorTokens.swift
//  AvocadoToast
//
//  Warm espresso/avocado palette with a parchment counterpart for light mode.
//  Every screen reads from these tokens so the Appearance setting changes the
//  actual interface, not merely the system chrome.
//

import SwiftUI

@MainActor
final class ColorTokens {
    private static var appearance: AppConfig.Appearance { AppConfig.shared.selectedAppearance }
    private static var usesWarmLight: Bool { appearance == .light }
    private static var usesSystem: Bool { appearance == .system }

    static var backgroundPrimary: Color {
        if usesWarmLight { return Color(red: 0.95, green: 0.92, blue: 0.86) }
        if usesSystem { return Color(.systemBackground) }
        return Color(red: 23/255, green: 22/255, blue: 18/255)
    }

    static var backgroundSecondary: Color {
        if usesWarmLight { return Color(red: 0.90, green: 0.86, blue: 0.78) }
        if usesSystem { return Color(.secondarySystemBackground) }
        return Color(red: 33/255, green: 31/255, blue: 25/255)
    }

    static var surfaceGlass: Color {
        if usesWarmLight { return Color.white.opacity(0.42) }
        if usesSystem { return Color(.systemBackground).opacity(0.08) }
        return Color(red: 245/255, green: 234/255, blue: 214/255).opacity(0.07)
    }

    static var surfaceElevated: Color {
        if usesWarmLight { return Color.white.opacity(0.58) }
        if usesSystem { return Color(.secondarySystemBackground).opacity(0.6) }
        return Color(red: 245/255, green: 234/255, blue: 214/255).opacity(0.11)
    }

    static var textPrimary: Color {
        if usesWarmLight { return Color(red: 57/255, green: 52/255, blue: 43/255) }
        if usesSystem { return Color(.label) }
        return Color(red: 244/255, green: 237/255, blue: 220/255)
    }

    static var textSecondary: Color {
        if usesWarmLight { return Color(red: 105/255, green: 97/255, blue: 83/255).opacity(0.9) }
        if usesSystem { return Color(.secondaryLabel) }
        return Color(red: 194/255, green: 184/255, blue: 165/255).opacity(0.78)
    }

    static var accentPrimary: Color {
        usesWarmLight ? Color(red: 104/255, green: 113/255, blue: 68/255) : Color(red: 174/255, green: 183/255, blue: 124/255)
    }
    static var accentMuted: Color { accentPrimary.opacity(0.24) }
    static var butter: Color {
        usesWarmLight ? Color(red: 175/255, green: 137/255, blue: 71/255) : Color(red: 224/255, green: 196/255, blue: 142/255)
    }
    static var toast: Color { Color(red: 155/255, green: 105/255, blue: 70/255) }
    static var separator: Color { textPrimary.opacity(usesWarmLight ? 0.12 : 0.09) }
    static var playerProgress: Color { butter }
    static var artworkPlaceholder: Color {
        usesWarmLight ? Color(red: 155/255, green: 146/255, blue: 128/255).opacity(0.38) : Color(red: 87/255, green: 80/255, blue: 63/255).opacity(0.38)
    }
    static var dimmed: Color { Color.black.opacity(usesWarmLight ? 0.22 : 0.38) }
}
