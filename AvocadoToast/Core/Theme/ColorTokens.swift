//
//  ColorTokens.swift
//  AvocadoToast
//
//  The dark palette is espresso, not cold charcoal. Warmth comes from olive,
//  butter and toasted tones, used sparingly.
//

import SwiftUI

@MainActor
final class ColorTokens {
    static let backgroundPrimary = Color(red: 23/255, green: 22/255, blue: 18/255) // espresso
    static let backgroundSecondary = Color(red: 33/255, green: 31/255, blue: 25/255) // dark roast
    static let surfaceGlass = Color(red: 245/255, green: 234/255, blue: 214/255).opacity(0.07)
    static let surfaceElevated = Color(red: 245/255, green: 234/255, blue: 214/255).opacity(0.11)

    static let textPrimary = Color(red: 244/255, green: 237/255, blue: 220/255) // warm ivory
    static let textSecondary = Color(red: 194/255, green: 184/255, blue: 165/255).opacity(0.78)

    static let accentPrimary = Color(red: 174/255, green: 183/255, blue: 124/255) // avocado
    static let accentMuted = Color(red: 174/255, green: 183/255, blue: 124/255).opacity(0.24)
    static let butter = Color(red: 224/255, green: 196/255, blue: 142/255)
    static let toast = Color(red: 155/255, green: 105/255, blue: 70/255)

    static let separator = Color(red: 244/255, green: 237/255, blue: 220/255).opacity(0.09)
    static let playerProgress = butter
    static let artworkPlaceholder = Color(red: 87/255, green: 80/255, blue: 63/255).opacity(0.38)
    static let dimmed = Color.black.opacity(0.38)
}
