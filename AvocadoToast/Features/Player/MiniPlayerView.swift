//
//  MiniPlayerView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import AVFoundation

/// Persistent floating mini-player. Shows the current track, playback state,
/// progress and play/pause. Tap to expand to the full player.
struct MiniPlayerView: View {
    @ObservedObject private var player = PlayerService.shared
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            if player.currentTrack != nil {
                miniPlayerContent
            }
        }
    }

    private var miniPlayerContent: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkURL = player.currentTrack?.artworkURL {
                CachedAsyncImage(url: artworkURL, size: CGSize(width: 56, height: 56)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentTrack?.title ?? "Unknown Track")
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(player.currentTrack?.artistName ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            // Progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 4)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: max(0, geo.size.width * player.progress), height: 4)
                }
            }
            .frame(height: 4)
            .onTapGesture { /* seek handled in full player */ }

            // Play/pause
            Button(action: { player.togglePlayPause() }) {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }

            // Next
            Button(action: { player.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color(.systemBackground).opacity(0.92)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: -4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            coordinator.showingNowPlaying = true
        }
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
