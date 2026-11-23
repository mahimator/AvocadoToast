//
//  NowPlayingView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI

/// Full-screen now-playing view with artwork, playback controls, queue and shuffle/repeat.
struct NowPlayingView: View {
    @ObservedObject private var player = PlayerService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Ambient background
            backgroundView
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top navigation glass bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button(action: { /* more actions */ }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 20)

                if let track = player.currentTrack {
                    // Artwork
                    artworkView(for: track)

                    VStack(spacing: 8) {
                        Text(track.title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(track.artistName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let album = track.albumName, !album.isEmpty {
                            Text(album)
                                .font(.subheadline)
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)

                    // Progress
                    VStack(spacing: 6) {
                        HStack {
                            Text(player.currentTime.formattedDuration)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let duration = track.duration {
                                Text(duration.formattedDuration)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Slider(value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ), in: 0...max((track.duration ?? 0), 1))
                        .tint(Color.accentColor)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 30)

                    // Primary controls
                    HStack(spacing: 36) {
                        Button(action: { player.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        Button(action: { player.togglePlayPause() }) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        Button(action: { player.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.top, 30)

                    // Secondary controls
                    HStack(spacing: 40) {
                        Button(action: { player.setShuffle(!player.isShuffleOn) }) {
                            Image(systemName: player.isShuffleOn ? "shuffle.fill" : "shuffle")
                                .font(.title3)
                                .foregroundStyle(player.isShuffleOn ? Color.accentColor : .secondary)
                        }
                        Button(action: { player.nextRepeatMode() }) {
                            Image(systemName: repeatIcon)
                                .font(.title3)
                                .foregroundStyle(player.repeatMode != .off ? Color.accentColor : .secondary)
                        }
                        Button(action: { /* queue */ }) {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 24)

                    Spacer(minLength: 30)
                } else {
                    ContentUnavailableView("No Track", systemImage: "music.note", description: Text("Select a track to play"))
                }
            }
        }
    }

    // MARK: - Subviews

    private var backgroundView: some View {
        Group {
            if let artworkURL = player.currentTrack?.artworkURL,
               let _ = ArtworkService.shared.imageInMemory(for: artworkURL) {
                // Colored ambient gradient placeholder; real artwork-driven background
                // would use the loaded image with a blur.
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func artworkView(for track: DomainTrack) -> some View {
        if let artworkURL = track.artworkURL {
            CachedAsyncImage(url: artworkURL, size: CGSize(width: 280, height: 280)) { image in
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
                } else {
                    placeholderArtwork
                }
            }
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 280, height: 280)
    }

    private var repeatIcon: String {
        switch player.repeatMode {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
}

// MARK: - Time interval formatting

extension TimeInterval {
    var formattedDuration: String {
        let total = Int(self)
        let m = total / 60, s = total % 60
        return m > 0 ? "\(m):\(s < 10 ? "0" : "")\(s)" : "\(s)s"
    }
}

extension PlayerService {
    /// Advance repeat mode cyclically.
    func nextRepeatMode() {
        switch repeatMode {
        case .off: setRepeat(.all)
        case .all: setRepeat(.one)
        case .one: setRepeat(.off)
        }
    }
}
