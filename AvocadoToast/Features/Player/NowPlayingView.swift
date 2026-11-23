//
//  NowPlayingView.swift
//  AvocadoToast
//
//  Full-screen listening room. Ambient colour is derived from the current artwork;
//  the rest of the app keeps its warm Avocado Toast palette.
//

import SwiftUI

struct NowPlayingView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var ambientColor: Color = ColorTokens.accentPrimary.opacity(0.22)

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 12)

                if let track = player.currentTrack {
                    artwork(for: track)
                        .padding(.horizontal, 26)
                        .padding(.bottom, 26)

                    trackInfo(track)
                        .padding(.horizontal, 28)

                    timeline
                        .padding(.horizontal, 28)
                        .padding(.top, 24)

                    playbackButton
                        .padding(.top, 26)

                    if let error = player.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                    }
                } else {
                    ContentUnavailableView("Nothing playing", systemImage: "music.note", description: Text("Find a track and let it take over from here."))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 24)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .task(id: player.currentTrack?.thumbnailURL) {
            await updateAmbientColor(for: player.currentTrack?.thumbnailURL)
        }
    }

    private func updateAmbientColor(for source: String?) async {
        guard let source, let url = URL(string: source) else {
            withAnimation(.easeInOut(duration: 0.6)) { ambientColor = ColorTokens.accentPrimary.opacity(0.22) }
            return
        }
        guard let sampled = await ArtworkService.shared.ambientColor(from: url) else { return }
        withAnimation(.easeInOut(duration: 0.85)) {
            ambientColor = sampled
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.22)))
            }
            .accessibilityLabel("Close player")
            Spacer()
            VStack(spacing: 3) {
                Text("NOW PLAYING")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(ambientColor.opacity(0.95))
                Text("A little listening room")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
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
                .strokeBorder(.white.opacity(0.16))
        }
        .shadow(color: ambientColor.opacity(0.35), radius: 30, y: 16)
    }

    private func trackInfo(_ track: YouTubeTrack) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(track.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(track.artist)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.72))
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
            .tint(ambientColor)
            HStack {
                Text(player.currentTime.formattedDuration)
                Spacer()
                Text(player.duration.formattedDuration)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.62))
        }
    }

    private var playbackButton: some View {
        Button { player.togglePlayPause() } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ColorTokens.backgroundPrimary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 76, height: 76)
                .background(ambientColor, in: Circle())
                .shadow(color: ambientColor.opacity(0.3), radius: 18, y: 7)
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
                    .foregroundStyle(.white.opacity(0.65))
            }
    }

    private var backdrop: some View {
        ZStack {
            Color(red: 0.055, green: 0.052, blue: 0.045)
            LinearGradient(
                colors: [ambientColor.opacity(0.72), ambientColor.opacity(0.18), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [ambientColor.opacity(0.45), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 520
            )
            RadialGradient(
                colors: [ColorTokens.toast.opacity(0.16), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 360
            )
            Rectangle().fill(.ultraThinMaterial).opacity(0.12)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: ambientColor)
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
