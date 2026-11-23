//
//  NowPlayingView.swift
//  AvocadoToast
//

import SwiftUI

struct NowPlayingView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 18)

                if let track = player.currentTrack {
                    artwork(for: track)
                        .padding(.horizontal, 26)
                        .padding(.bottom, 30)

                    trackInfo(track)
                        .padding(.horizontal, 28)

                    timeline
                        .padding(.horizontal, 28)
                        .padding(.top, 26)

                    playbackButton
                        .padding(.top, 24)

                    if let error = player.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                    }
                } else {
                    ContentUnavailableView("Nothing playing", systemImage: "music.note", description: Text("Find a track and let it take over from here."))
                        .foregroundStyle(ColorTokens.textPrimary)
                }

                Spacer(minLength: 28)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(ColorTokens.separator))
            }
            .accessibilityLabel("Close player")
            Spacer()
            VStack(spacing: 3) {
                Text("NOW PLAYING")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(ColorTokens.accentPrimary)
                Text("A little listening room")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func artwork(for track: YouTubeTrack) -> some View {
        Group {
            if let artworkURL = track.thumbnailURL.flatMap({ URL(string: $0) }) {
                CachedAsyncImage(url: artworkURL, size: CGSize(width: 360, height: 360)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(ColorTokens.textPrimary.opacity(0.09))
        }
        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
    }

    private func trackInfo(_ track: YouTubeTrack) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(track.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(track.artist)
                .font(.headline)
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(1)
        }
    }

    private var timeline: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .tint(ColorTokens.butter)
            HStack {
                Text(player.currentTime.formattedDuration)
                Spacer()
                Text(player.duration.formattedDuration)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private var playbackButton: some View {
        Button { player.togglePlayPause() } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ColorTokens.backgroundPrimary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 76, height: 76)
                .background(ColorTokens.butter, in: Circle())
                .shadow(color: ColorTokens.butter.opacity(0.22), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause playback" : "Play")
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(ColorTokens.surfaceElevated)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 54, weight: .ultraLight))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
    }

    private var backdrop: some View {
        ZStack {
            ColorTokens.backgroundPrimary
            RadialGradient(
                colors: [ColorTokens.accentPrimary.opacity(0.22), .clear],
                center: .top,
                startRadius: 12,
                endRadius: 520
            )
            RadialGradient(
                colors: [ColorTokens.toast.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 360
            )
            Rectangle().fill(.ultraThinMaterial).opacity(0.15)
        }
        .ignoresSafeArea()
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let secondsTotal = max(0, Int(self))
        let minutes = secondsTotal / 60
        let seconds = secondsTotal % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}
