//
//  Typography.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import UIKit

@MainActor
enum AppFont: String {
    case displayLarge = "DisplayLarge"
    case displayMedium = "DisplayMedium"
    case displaySmall = "DisplaySmall"
    case headline = "Headline"
    case title = "Title"
    case title2 = "Title2"
    case title3 = "Title3"
    case body = "Body"
    case callout = "Callout"
    case subheadline = "Subheadline"
    case footnote = "Footnote"
    
    var uiFont: UIFont {
        UIFont.systemFont(ofSize: 17, weight: .regular)
    }
}

@MainActor
enum TextStyle {
    case displayLarge, displayMedium, displaySmall, headline, title, title2, title3, body, callout, subheadline, footnote, caption, caption2
    
    var font: Font {
        switch self {
        case .displayLarge: return .system(size: 34, weight: .bold)
        case .displayMedium: return .system(size: 28, weight: .bold)
        case .displaySmall: return .system(size: 22, weight: .bold)
        case .headline: return .system(size: 17, weight: .bold)
        case .title: return .system(size: 17, weight: .semibold)
        case .title2: return .system(size: 15, weight: .semibold)
        case .title3: return .system(size: 13, weight: .semibold)
        case .body: return .system(size: 17, weight: .regular)
        case .callout: return .system(size: 16, weight: .regular)
        case .subheadline: return .system(size: 15, weight: .regular)
        case .footnote: return .system(size: 13, weight: .regular)
        case .caption: return .system(size: 12, weight: .regular)
        case .caption2: return .system(size: 11, weight: .regular)
        }
    }
    
    var color: Color {
        switch self {
        case .headline, .title, .title2, .title3, .body, .callout, .subheadline, .footnote,
             .displayLarge, .displayMedium, .displaySmall: return .primary
        case .caption, .caption2: return .secondary
        }
    }
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        self.font(style.font).foregroundColor(style.color)
    }
}
