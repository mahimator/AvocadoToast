//
//  PlayerService.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import AVFoundation
import Combine

/// Playback state machine.
enum PlaybackState: String, CaseIterable, Sendable {
    case idle     = "Idle"
    case loading  = "Loading"
    case ready    = "Ready"
    case playing  = "Playing"
    case paused   = "Paused"
    case buffering = "Buffering"
    case failed   = "Failed"
    case ended    = "Ended"
}

/// Repeat mode.
enum RepeatMode: String, CaseIterable, Sendable {
    case off    = "Off"
    case one    = "One"
    case all    = "All"
}

/// A queue item backed by a domain track.
struct QueueItem: Identifiable, Equatable, Hashable {
    let id: String
    let track: DomainTrack
    init(track: DomainTrack) {
        self.id = track.id + "|" + track.provider
        self.track = track
    }
    static func == (lhs: QueueItem, rhs: QueueItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Player service: owns the queue, playback state machine and AVPlayer engine.
/// Playback of catalog tracks requires an actual audio source; where none is
/// available the player reports an honest "failed/unavailable" state rather
/// than faking success.
@MainActor
final class PlayerService: ObservableObject {
    static let shared = PlayerService()

    // Published state
    @Published private(set) var playbackState: PlaybackState = .idle
    @Published private(set) var queue: [QueueItem] = []
    @Published private(set) var currentIndex: Int? = nil
    @Published private(set) var isShuffleOn: Bool = false
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var progress: Double = 0.0      // 0...1
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var errorMessage: String? = nil

    var currentTrack: DomainTrack? {
        guard let idx = currentIndex, idx >= 0, idx < queue.count else { return nil }
        return queue[idx].track
    }
    var isPlaying: Bool { playbackState == .playing }

    // AV engine
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var progressTimer: Timer?

    private init() {
        setupObservers()
    }

    // MARK: - Queue

    func setQueue(_ tracks: [DomainTrack], startAt index: Int = 0) {
        stop()
        queue = tracks.map { QueueItem(track: $0) }
        currentIndex = max(0, min(index, queue.count - 1))
        if let currentTrack {
            load(track: currentTrack)
        } else {
            playbackState = .idle
        }
    }

    func appendToQueue(_ tracks: [DomainTrack]) {
        queue.append(contentsOf: tracks.map { QueueItem(track: $0) })
    }

    func insertNext(_ track: DomainTrack) {
        let insertAt = (currentIndex ?? -1) + 1
        queue.insert(QueueItem(track: track), at: max(0, insertAt))
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        queue.remove(at: index)
        if let current = currentIndex {
            if index < current { currentIndex = current - 1 }
            else if index == current { currentIndex = nil; stop() }
        }
        if queue.isEmpty { currentIndex = nil; playbackState = .idle }
    }

    func clearQueue() {
        stop()
        queue.removeAll()
        currentIndex = nil
    }

    func moveQueueItem(from source: Int, to destination: Int) {
        guard source >= 0, source < queue.count,
              destination >= 0, destination < queue.count,
              source != destination else { return }
        let item = queue.remove(at: source)
        queue.insert(item, at: destination)
        if let current = currentIndex {
            if source == current { currentIndex = destination }
            else if source < current && destination >= current { currentIndex = current - 1 }
            else if source > current && destination <= current { currentIndex = current + 1 }
        }
    }

    func setShuffle(_ on: Bool) {
        isShuffleOn = on
        if on {
            // Fisher-Yates shuffle keeping current track at its position
            guard queue.count > 1, let current = currentIndex else { return }
            let currentTrack = queue.remove(at: current)
            queue.shuffle()
            queue.insert(currentTrack, at: 0)
            currentIndex = 0
        }
    }

    func setRepeat(_ mode: RepeatMode) {
        repeatMode = mode
    }

    // MARK: - Playback control

    func play(_ track: DomainTrack) {
        // If already in queue, jump to it; otherwise append and play
        if let idx = queue.firstIndex(where: { $0.track.id == track.id && $0.track.provider == track.provider }) {
            currentIndex = idx
        } else {
            appendToQueue([track])
            currentIndex = queue.count - 1
        }
        guard let currentTrack else { return }
        load(track: currentTrack)
        playEngine()
    }

    func play() {
        guard let currentTrack else { return }
        playEngine()
    }

    func pause() {
        player.pause()
        playbackState = .paused
        stopProgressTimer()
        errorMessage = nil
    }

    func togglePlayPause() {
        if playbackState == .playing { pause() } else { playEngine() }
    }

    func previousTrack() {
        guard !queue.isEmpty else { return }
        if let current = currentIndex, current > 0 {
            currentIndex = current - 1
        } else {
            currentIndex = repeatMode == .all ? (queue.count - 1) : 0
        }
        guard let track = currentTrack else { return }
        load(track: track)
        playEngine()
    }

    func nextTrack() {
        guard !queue.isEmpty else { return }
        if let current = currentIndex {
            let next = current + 1
            if next < queue.count {
                currentIndex = next
            } else {
                switch repeatMode {
                case .all: currentIndex = 0
                case .one: break // same track
                case .off:
                    currentIndex = nil
                    stop()
                    playbackState = .ended
                    return
                }
            }
        } else {
            currentIndex = 0
        }
        guard let track = currentTrack else { return }
        load(track: track)
        playEngine()
    }

    func seek(to position: TimeInterval) {
        guard let currentTrack else { return }
        let cmTime = CMTime(seconds: position, preferredTimescale: 1000)
        player.seek(to: cmTime)
    }

    func seek(progress fraction: Double) {
        guard let currentTrack, let duration = currentTrack.duration, duration > 0 else { return }
        seek(to: fraction * duration)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        playbackState = .idle
        currentTime = 0
        progress = 0
        stopProgressTimer()
        errorMessage = nil
    }

    // MARK: - Internal engine

    private func load(track: DomainTrack) {
        playbackState = .loading
        errorMessage = nil
        stopProgressTimer()

        // Build a playable URL. Catalog metadata provides an artwork URL but not
        // an audio stream URL. Without a real audio-source provider we cannot
        // actually play; we report this honestly.
        guard let url = audioURL(for: track) else {
            playbackState = .failed
            errorMessage = "Playback source unavailable for this track"
            return
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        playbackState = .ready
    }

    func playEngine() {
        guard let currentTrack else { return }
        guard audioURL(for: currentTrack) != nil else {
            playbackState = .failed
            errorMessage = "Playback source unavailable for this track"
            return
        }
        player.play()
        playbackState = .playing
        startProgressTimer()
    }

    private func audioURL(for track: DomainTrack) -> URL? {
        // The SRS separates catalog metadata from playback. ytmusicapi provides
        // metadata only; actual audio extraction is out of scope (non-goal).
        // Return nil so the player reports an honest unavailable state rather
        // than faking success. A real provider can be plugged in here later.
        nil
    }

    // MARK: - Progress observation

    private func setupObservers() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleTrackEnded() }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                if let duration = self?.currentTrack?.duration, duration > 0 {
                    self?.progress = max(0, min(1, time.seconds / duration))
                }
            }
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = self.player.currentTime().seconds
                if let duration = self.currentTrack?.duration, duration > 0 {
                    self.progress = max(0, min(1, self.currentTime / duration))
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func handleTrackEnded() {
        if repeatMode == .one {
            // Replay same track
            player.seek(to: .zero)
            player.play()
            playbackState = .playing
            return
        }
        nextTrack()
    }

    deinit {
        if let observer = timeObserver { player.removeTimeObserver(observer) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}
