//
//  MiniPlayerView.swift
//  AvocadoToast
//

import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var config = AppConfig.shared
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let track = player.currentTrack {
                HStack(spacing: 11) {
                    artwork(for: track)
                    Button { coordinator.showingNowPlaying = true } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                            .frame(width: 42, height: 42)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                }
                .padding(10)
                .background(config.enableGlassEffects ? ColorTokens.surfaceGlass : ColorTokens.backgroundSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(ColorTokens.textPrimary.opacity(0.08))
                }
                .shadow(color: .black.opacity(0.22), radius: 14, y: 5)
            }
        }
    }

    @ViewBuilder
    private func artwork(for track: YouTubeTrack) -> some View {
        if let artworkURL = track.thumbnailURL.flatMap({ URL(string: $0) }) {
            CachedAsyncImage(url: artworkURL, size: CGSize(width: 48, height: 48)) { image in
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(ColorTokens.artworkPlaceholder)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(width: 48, height: 48)
    }
}
