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
            background
            VStack(spacing: 0) {
                header
                Spacer(minLength: 20)
                if let track = player.currentTrack {
                    artwork(track)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 34)
                    VStack(spacing: 8) {
                        Text(track.title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(track.artist)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    progressControl
                        .padding(.horizontal, 28)
                        .padding(.top, 26)
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 78, height: 78)
                            .background(ColorTokens.accentPrimary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Pause playback" : "Start playback")
                    .padding(.top, 26)
                    if let message = player.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }
                } else {
                    ContentUnavailableView("Nothing playing", systemImage: "music.note", description: Text("Choose something from Search to get started."))
                }
                Spacer(minLength: 36)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(.thinMaterial, in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.caption2.weight(.bold))
                    .tracking(1.8)
                Text("AvocadoToast")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .font(.headline)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: Circle())
                .opacity(0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var progressControl: some View {
        VStack(spacing: 7) {
            Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                   in: 0...max(player.duration, 1))
                .tint(ColorTokens.accentPrimary)
            HStack {
                Text(player.currentTime.formattedDuration)
                Spacer()
                Text(player.duration.formattedDuration)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func artwork(_ track: YouTubeTrack) -> some View {
        if let url = track.thumbnailURL.flatMap({ URL(string: $0) }) {
            CachedAsyncImage(url: url, size: CGSize(width: 340, height: 340)) { image in
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
                } else { artworkPlaceholder }
            }
        } else { artworkPlaceholder }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    private var background: some View {
        LinearGradient(colors: [ColorTokens.accentPrimary.opacity(0.24), Color(.systemBackground), Color(.systemGroupedBackground)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(.ultraThinMaterial.opacity(0.3))
            .ignoresSafeArea()
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let total = max(0, Int(self))
        let minutes = total / 60
        let seconds = total % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}
