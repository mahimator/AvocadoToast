//
//  GlassStyles.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
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
    
    static let elevatedShadow: Shadow = Shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    static let deepShadow: Shadow = Shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    static let noShadow: Shadow = .init(color: .clear, radius: 0, x: 0, y: 0)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct GlassBackground: View {
    let blur: CGFloat, opacity: Double, cornerRadius: CGFloat, expanded: Bool
    init(blur: CGFloat = 10, opacity: Double = 0.08, cornerRadius: CGFloat = 16, expanded: Bool = false) {
        self.blur = blur; self.opacity = opacity; self.cornerRadius = cornerRadius; self.expanded = expanded
    }
    var body: some View {
        Rectangle().fill(Color.white.opacity(opacity)).background(.ultraThinMaterial)
            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .frame(maxWidth: expanded ? .infinity : nil, maxHeight: expanded ? 200 : 100)
            .overlay(
                LinearGradient(colors: [Color.white.opacity(0.05), .clear, Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
            ).clipped()
    }
}

struct GlassCard<Content: View>: View {
    let cornerRadius, opacity: Double, showsShadow: Bool, content: () -> Content
    init(cornerRadius: CGFloat = 16, opacity: Double = 0.08, showsShadow: Bool = true, content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius; self.opacity = opacity; self.showsShadow = showsShadow; self.content = content
    }
    var body: some View {
        VStack { content() }
            .background(GlassBackground(blur: 10, opacity: opacity, cornerRadius: cornerRadius, expanded: false))
            .cornerRadius(cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: showsShadow ? Color.black.opacity(0.3) : .clear,
                    radius: showsShadow ? 4 : 0, x: 0, y: showsShadow ? 2 : 0)
    }
}