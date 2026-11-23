//
//  MiniPlayerView.swift
//  AvocadoToast
//

import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let track = player.currentTrack {
                HStack(spacing: 12) {
                    artwork(track)
                    Button {
                        coordinator.showingNowPlaying = true
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 42, height: 42)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.16)))
                .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
            }
        }
    }

    @ViewBuilder
    private func artwork(_ track: YouTubeTrack) -> some View {
        if let url = track.thumbnailURL.flatMap({ URL(string: $0) }) {
            CachedAsyncImage(url: url, size: CGSize(width: 48, height: 48)) { image in
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 10))
                } else { placeholder }
            }
        } else { placeholder }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.18)).frame(width: 48, height: 48)
    }
}
