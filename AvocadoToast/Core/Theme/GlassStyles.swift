//
//  GlassStyles.swift
//  AvocadoToast
//

import SwiftUI

@MainActor
final class GlassStyles {
    static let standardMaterial: Material = .ultraThinMaterial
    static let elevatedMaterial: Material = .thinMaterial
    static let overlayMaterial: Material = .regularMaterial

    static let glassOpacity: Double = 0.08
    static let elevatedOpacity: Double = 0.12
    static let overlayOpacity: Double = 0.15

    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 20
    static let minimalCornerRadius: CGFloat = 8

    static let elevatedShadow = Shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    static let deepShadow = Shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    static let noShadow = Shadow(color: .clear, radius: 0, x: 0, y: 0)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct GlassBackground: View {
    @ObservedObject private var config = AppConfig.shared
    let blur: CGFloat
    let opacity: Double
    let cornerRadius: CGFloat
    let expanded: Bool

    init(blur: CGFloat = 10, opacity: Double = 0.08, cornerRadius: CGFloat = 16, expanded: Bool = false) {
        self.blur = blur
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.expanded = expanded
    }

    var body: some View {
        Rectangle()
            .fill(ColorTokens.textPrimary.opacity(config.enableGlassEffects ? opacity : 0.12))
            .background {
                if config.enableGlassEffects {
                    Rectangle().fill(.ultraThinMaterial)
                } else {
                    ColorTokens.backgroundSecondary
                }
            }
            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .frame(maxWidth: expanded ? .infinity : nil, maxHeight: expanded ? 200 : 100)
            .overlay {
                LinearGradient(
                    colors: [ColorTokens.textPrimary.opacity(0.05), .clear, ColorTokens.textPrimary.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipped()
    }
}

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let opacity: Double
    let showsShadow: Bool
    let content: () -> Content

    init(cornerRadius: CGFloat = 16, opacity: Double = 0.08, showsShadow: Bool = true, content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.showsShadow = showsShadow
        self.content = content
    }

    var body: some View {
        VStack { content() }
            .background(GlassBackground(blur: 10, opacity: opacity, cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorTokens.textPrimary.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: showsShadow ? Color.black.opacity(0.3) : .clear,
                    radius: showsShadow ? 4 : 0, x: 0, y: showsShadow ? 2 : 0)
    }
}
