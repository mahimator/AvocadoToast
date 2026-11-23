//
//  SectionView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI

/// Horizontal carousel section on the Home screen.
struct SectionView: View {
    let section: HomeSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(section.title)
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("See All") { /* navigate to full section */ }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(section.items, id: \.id) { item in
                        HomeItemCard(item: item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Home item card

struct HomeItemCard: View {
    let item: MusicEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artworkURL = item.artwork.flatMap { URL(string: $0) } {
                CachedAsyncImage(url: artworkURL, size: CGSize(width: 150, height: 150)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }

            Text(item.title)
                .font(.body.weight(.medium))
                .lineLimit(2)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150)
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 150, height: 150)
    }
}
