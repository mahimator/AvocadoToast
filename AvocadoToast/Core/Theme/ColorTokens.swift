//
//  ColorTokens.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI

@MainActor
final class ColorTokens {
    // Surface colors
    static let backgroundPrimary: Color = Color(red: 10/255, green: 10/255, blue: 15/255)
    static let backgroundSecondary: Color = Color(red: 15/255, green: 15/255, blue: 20/255)
    static let surfaceGlass: Color = Color.white.opacity(0.08)
    static let surfaceElevated: Color = Color.white.opacity(0.12)
    
    // Text colors
    static let textPrimary: Color = Color.white
    static let textSecondary: Color = Color.white.opacity(0.6)
    
    // Accent colors
    static let accentPrimary: Color = Color(red: 239/255, green: 139/255, blue: 87/255)
    static let accentMuted: Color = Color(red: 239/255, green: 139/255, blue: 87/255).opacity(0.3)
    
    // Separator and player progress
    static let separator: Color = Color.white.opacity(0.1)
    static let playerProgress: Color = Color(red: 239/255, green: 139/255, blue: 87/255)
    
    // Artwork placeholder
    static let artworkPlaceholder: Color = Color.gray.opacity(0.2)
    static let dimmed: Color = Color.black.opacity(0.3)
}