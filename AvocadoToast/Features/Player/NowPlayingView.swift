//
//  NowPlayingView.swift
//  AvocadoToast
//
//  Full-screen listening room. Ambient colour is derived from the current artwork;
//  the rest of the app keeps its warm Avocado Toast palette.
//

import SwiftUI
import AVKit

struct NowPlayingView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var ambientColor: Color = ColorTokens.accentPrimary.opacity(0.22)
    @State private var showingQueue = false
    @State private var showingLyrics = false
    @ObservedObject private var catalog = CatalogService.shared
    @ObservedObject private var config = AppConfig.shared

    var body: some View {
        ZStack {
            backdrop
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                        .padding(.bottom, 20)

                    if let track = player.currentTrack {
                        artwork(for: track)
                            .frame(maxWidth: 360)
                            .padding(.horizontal, 26)
                            .padding(.bottom, 26)

                        trackInfo(track)
                            .padding(.horizontal, 28)

                        timeline
                            .padding(.horizontal, 28)
                            .padding(.top, 24)

                        playbackControls
                            .padding(.top, 26)
                        secondaryControls
                            .padding(.top, 18)
                        lyricsButton
                            .padding(.top, 16)

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
                            .padding(.top, 80)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 36)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .task(id: player.currentTrack?.videoId) {
            await updateAmbientColor(for: player.currentTrack?.thumbnailURL)
        }
        .sheet(isPresented: $showingQueue) {
            QueueSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingLyrics) {
            if let track = player.currentTrack {
                LyricsSheet(track: track)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func updateAmbientColor(for source: String?) async {
        guard config.artworkBackgroundEnabled, let source, let url = URL(string: source) else {
            setAmbientColor(ColorTokens.accentPrimary.opacity(0.22))
            return
        }
        guard let sampled = await ArtworkService.shared.ambientColor(from: url) else {
            setAmbientColor(ColorTokens.accentPrimary.opacity(0.22))
            return
        }
        setAmbientColor(sampled)
    }

    private func setAmbientColor(_ color: Color) {
        withAnimation(config.reduceMotion ? nil : .easeInOut(duration: 0.85)) {
            ambientColor = color
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

    private var playbackControls: some View {
        HStack(spacing: 28) {
            playerSkipButton(
                symbol: "backward.fill",
                label: "Previous track",
                disabled: player.currentTime <= 3 && !catalog.canPlayPrevious
            ) {
                catalog.playPrevious()
            }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(ColorTokens.backgroundPrimary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 76, height: 76)
                    .background(ambientColor, in: Circle())
                    .shadow(color: ambientColor.opacity(0.3), radius: 18, y: 7)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause playback" : "Play")
            playerSkipButton(
                symbol: "forward.fill",
                label: "Next track",
                disabled: !catalog.canPlayNext
            ) {
                catalog.playNext()
            }
        }
    }

    private var secondaryControls: some View {
        HStack(spacing: 0) {
            Button { catalog.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(catalog.shuffleEnabled ? ambientColor : .white.opacity(0.65))
                    .frame(width: 52, height: 42)
            }
            .accessibilityLabel(catalog.shuffleEnabled ? "Turn shuffle off" : "Turn shuffle on")
            Spacer()
            Button { catalog.cycleRepeatMode() } label: {
                Image(systemName: catalog.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(catalog.repeatMode == .off ? .white.opacity(0.65) : ambientColor)
                    .frame(width: 52, height: 42)
            }
            .accessibilityLabel("Repeat mode: \(catalog.repeatMode.rawValue)")
            Spacer()
            Button { showingQueue = true } label: {
                Image(systemName: "list.bullet")
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 52, height: 42)
            }
            .accessibilityLabel("Open queue")
            Spacer()
            AirPlayRoutePicker()
                .frame(width: 52, height: 42)
                .accessibilityLabel("AirPlay and audio output")
        }
        .padding(.horizontal, 36)
    }

    private var lyricsButton: some View {
        Button { showingLyrics = true } label: {
            Label("Lyrics", systemImage: "quote.bubble")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func playerSkipButton(symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 48, height: 48)
                .opacity(disabled ? 0.3 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
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
        .animation(config.reduceMotion ? nil : .easeInOut(duration: 0.8), value: ambientColor)
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


private struct QueueSheet: View {
    @ObservedObject private var catalog = CatalogService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @State private var confirmingClearUpcoming = false

    var body: some View {
        NavigationStack {
            List {
                if catalog.playbackQueue.isEmpty {
                    ContentUnavailableView("Queue is empty", systemImage: "music.note.list", description: Text("Play a playlist to fill the queue."))
                } else {
                    ForEach(Array(catalog.playbackQueue.enumerated()), id: \.offset) { index, track in
                        Button {
                            Task { await catalog.playQueue(catalog.playbackQueue, startAt: index) }
                        } label: {
                            HStack(spacing: 12) {
                                if let url = track.thumbnailURL.flatMap(URL.init(string:)) {
                                    CachedAsyncImage(url: url, size: CGSize(width: 48, height: 48)) { image in
                                        if let image {
                                            Image(uiImage: image).resizable().scaledToFill()
                                                .frame(width: 48, height: 48)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            queueArtworkPlaceholder
                                        }
                                    }
                                } else {
                                    queueArtworkPlaceholder
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .lineLimit(1)
                                        .font(.subheadline.weight(.semibold))
                                    Text(track.artist)
                                        .lineLimit(1)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if index == catalog.queueIndex {
                                    Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                                        .foregroundStyle(ColorTokens.accentPrimary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                catalog.removeQueuedTrack(at: index)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .disabled(index == catalog.queueIndex)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear Upcoming") {
                        confirmingClearUpcoming = true
                    }
                    .disabled(catalog.playbackQueue.count <= catalog.queueIndex + 1)
                }
            }
            .confirmationDialog("Clear upcoming tracks?", isPresented: $confirmingClearUpcoming, titleVisibility: .visible) {
                Button("Clear Upcoming", role: .destructive) {
                    catalog.clearUpcoming()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The current song will keep playing.")
            }
            .navigationTitle("Up next")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var queueArtworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(ColorTokens.surfaceElevated)
            .frame(width: 48, height: 48)
            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
    }
}


private struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .white.withAlphaComponent(0.72)
        picker.activeTintColor = UIColor(ColorTokens.accentPrimary)
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}


private struct LyricsSheet: View {
    let track: YouTubeTrack
    @ObservedObject private var player = AudioPlayerService.shared
    @State private var segments: [YouTubeTranscriptSegment] = []
    @State private var isLoading = true

    private var activeIndex: Int? {
        let current = Int(player.currentTime * 1000)
        return segments.lastIndex(where: { $0.startMilliseconds <= current })
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Looking for lyrics…")
                            .foregroundStyle(.secondary)
                    }
                } else if segments.isEmpty {
                    ContentUnavailableView(
                        "Lyrics unavailable",
                        systemImage: "quote.bubble",
                        description: Text("This track doesn't have accessible captions right now.")
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                                    Button {
                                        player.seek(to: Double(segment.startMilliseconds) / 1000)
                                    } label: {
                                        Text(segment.text)
                                            .font(.system(size: 21, weight: index == activeIndex ? .semibold : .medium, design: .rounded))
                                            .foregroundStyle(index == activeIndex ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 26)
                        }
                        .onChange(of: activeIndex) { _, index in
                            guard let index, player.isPlaying else { return }
                            withAnimation(AppConfig.shared.reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(track.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: track.videoId) {
            isLoading = true
            segments = track.provider == "youtube" ? await YouTubeKitService.shared.fetchLyrics(videoId: track.videoId) : []
            isLoading = false
        }
    }
}
