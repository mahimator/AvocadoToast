//
//  AudioPlayerService.swift
//  AvocadoToast
//
//  Local files use AVAudioEngine (including the 10-band EQ).
//  Legitimate remote media URLs use AVPlayer, which supports streaming.
//

import Foundation
import Combine
import AVFoundation
import MediaPlayer

@MainActor
final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private let remotePlayer = AVPlayer()

    @Published var isPlaying = false
    @Published var currentTrack: YouTubeTrack?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackNext: (() -> Void)?
    var onPlaybackPrevious: (() -> Void)?

    private var audioFile: AVAudioFile?
    private var remoteTimeObserver: Any?
    private var finishObserver: NSObjectProtocol?
    private var bufferIsLoaded = false
    private var isRemotePlayback = false
    private var progressTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var itemStatusObservation: NSKeyValueObservation?
    private var shouldResumeAfterInterruption = false

    private let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    @Published var eqGains: [Float] = Array(repeating: 0, count: 10)

    private init() {
        setupEngine()
        setupEQ()
        setupRemoteObservers()
        configureRemoteCommands()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
            setupSessionObservers(session)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
        }
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.connect(playerNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
        } catch {
            errorMessage = "Audio engine start failed: \(error.localizedDescription)"
        }
    }

    private func setupEQ() {
        for (index, frequency) in eqFrequencies.enumerated() {
            eqNode.bands[index].frequency = frequency
            eqNode.bands[index].gain = eqGains[index]
            eqNode.bands[index].bypass = false
        }
    }

    private func setupRemoteObservers() {
        remoteTimeObserver = remotePlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, self.isRemotePlayback else { return }
                let seconds = time.seconds
                if seconds.isFinite { self.currentTime = max(0, seconds) }
                if let itemDuration = self.remotePlayer.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.updateNowPlayingInfo()
            }
        }

        finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      (notification.object as? AVPlayerItem) === self.remotePlayer.currentItem else { return }
                self.isPlaying = false
                self.currentTime = self.duration
                self.updateNowPlayingInfo()
                self.onPlaybackFinished?()
            }
        }
    }

    func play(_ track: YouTubeTrack) async {
        stopPlaybackOnly()
        currentTrack = track
        errorMessage = nil
        currentTime = 0
        duration = 0
        updateNowPlayingMetadata(for: track)

        if let localPath = track.localFileURL, !localPath.isEmpty {
            playLocalFile(at: URL(fileURLWithPath: localPath))
            return
        }

        guard let streamURL = track.streamURL,
              let url = URL(string: streamURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            errorMessage = "This track has no valid playback source."
            return
        }

        playRemoteURL(url)
    }

    private func playLocalFile(at url: URL) {
        guard url.isFileURL else {
            errorMessage = "Local playback requires a file URL."
            return
        }
        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            duration = Double(file.length) / file.processingFormat.sampleRate
            bufferIsLoaded = true
            isRemotePlayback = false
            playLocalEngine()
        } catch {
            audioFile = nil
            bufferIsLoaded = false
            errorMessage = "Couldn't open local audio: \(error.localizedDescription)"
        }
    }

    private func playRemoteURL(_ url: URL) {
        isRemotePlayback = true
        bufferIsLoaded = false
        audioFile = nil
        playerNode.stop()
        itemStatusObservation?.invalidate()
        let item = AVPlayerItem(url: url)
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.remotePlayer.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    let itemDuration = item.duration.seconds
                    if itemDuration.isFinite && itemDuration > 0 { self.duration = itemDuration }
                    self.updateNowPlayingInfo()
                case .failed:
                    self.errorMessage = item.error?.localizedDescription ?? "This audio source couldn't be played."
                    self.isPlaying = false
                    self.updateNowPlayingInfo()
                default:
                    break
                }
            }
        }
        remotePlayer.allowsExternalPlayback = true
        remotePlayer.replaceCurrentItem(with: item)
        remotePlayer.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    private func playLocalEngine() {
        guard bufferIsLoaded, let audioFile else {
            errorMessage = "The local audio file isn't ready."
            return
        }
        playerNode.stop()
        let trackID = currentTrack?.videoId
        playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
            Task { @MainActor in
                guard let self, self.currentTrack?.videoId == trackID, !self.isRemotePlayback else { return }
                self.isPlaying = false
                self.currentTime = self.duration
                self.stopProgressTimer()
                self.updateNowPlayingInfo()
                self.onPlaybackFinished?()
            }
        }
        playerNode.volume = 1
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            errorMessage = "Audio engine couldn't restart: \(error.localizedDescription)"
            return
        }
        playerNode.play()
        isPlaying = true
        startProgressTimer()
        updateNowPlayingInfo()
    }

    func pause() {
        if isRemotePlayback {
            remotePlayer.pause()
        } else {
            playerNode.pause()
            updateLocalPlaybackTime()
        }
        isPlaying = false
        stopProgressTimer()
        updateNowPlayingInfo()
    }

    func resume() {
        guard currentTrack != nil else { return }
        if isRemotePlayback, remotePlayer.currentItem != nil {
            remotePlayer.play()
            isPlaying = true
            updateNowPlayingInfo()
        } else if bufferIsLoaded {
            playerNode.play()
            isPlaying = true
            startProgressTimer()
            updateNowPlayingInfo()
        } else if let currentTrack {
            Task { await play(currentTrack) }
        }
    }

    func stop() {
        stopPlaybackOnly()
        currentTrack = nil
        currentTime = 0
        duration = 0
        errorMessage = nil
        updateNowPlayingInfo()
    }

    private func stopPlaybackOnly() {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        remotePlayer.pause()
        remotePlayer.replaceCurrentItem(with: nil)
        playerNode.stop()
        stopProgressTimer()
        isPlaying = false
        bufferIsLoaded = false
        isRemotePlayback = false
        audioFile = nil
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func seek(to time: Double) {
        let target = min(max(0, time), max(duration, 0))
        if isRemotePlayback {
            remotePlayer.seek(to: CMTime(seconds: target, preferredTimescale: 600))
            currentTime = target
        } else if let audioFile {
            let sampleRate = audioFile.processingFormat.sampleRate
            let frame = AVAudioFramePosition(target * sampleRate)
            guard frame >= 0, frame < audioFile.length else { return }
            let remaining = audioFile.length - frame
            guard remaining > 0 else { return }
            playerNode.stop()
            let count = AVAudioFrameCount(remaining)
            playerNode.scheduleSegment(audioFile, startingFrame: frame, frameCount: count, at: nil, completionHandler: nil)
            currentTime = target
            if isPlaying { playerNode.play() }
            updateLocalPlaybackTime()
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateLocalPlaybackTime() }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateLocalPlaybackTime() {
        guard !isRemotePlayback,
              let renderTime = playerNode.lastRenderTime,
              let nodeTime = playerNode.playerTime(forNodeTime: renderTime),
              nodeTime.sampleRate > 0 else { return }
        currentTime = min(duration, max(0, Double(nodeTime.sampleTime) / nodeTime.sampleRate))
        updateNowPlayingInfo()
    }

    // MARK: - Audio session lifecycle

    private func setupSessionObservers(_ session: AVAudioSession) {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let info = notification.userInfo,
                      let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
                switch type {
                case .began:
                    self.shouldResumeAfterInterruption = self.isPlaying
                    if self.isPlaying { self.pause() }
                case .ended:
                    let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                    if self.shouldResumeAfterInterruption && options.contains(.shouldResume) {
                        self.resume()
                    }
                    self.shouldResumeAfterInterruption = false
                @unknown default:
                    self.shouldResumeAfterInterruption = false
                }
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let info = notification.userInfo,
                      let rawReason = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable,
                      let previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else { return }
                let wasPersonalAudio = previousRoute.outputs.contains { output in
                    [.headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .usbAudio].contains(output.portType)
                }
                if wasPersonalAudio && self.isPlaying { self.pause() }
            }
        }
    }

    // MARK: - Lock Screen / headset / car controls

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlaybackNext?() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlaybackPrevious?() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func updateNowPlayingMetadata(for track: YouTubeTrack) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        if track.duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = track.duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        guard let artworkURL = track.thumbnailURL.flatMap(URL.init(string:)) else { return }
        Task { [weak self] in
            guard let self,
                  let artwork = await ArtworkService.shared.loadArtwork(from: artworkURL, size: CGSize(width: 512, height: 512)),
                  self.currentTrack?.videoId == track.videoId else { return }
            let lockScreenArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            updated[MPMediaItemPropertyArtwork] = lockScreenArtwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
        }
    }

    private func updateNowPlayingInfo() {
        guard currentTrack != nil else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func setEQGain(band: Int, gain: Float) {
        guard band >= 0, band < eqFrequencies.count else { return }
        let clampedGain = min(12, max(-12, gain))
        eqGains[band] = clampedGain
        eqNode.bands[band].gain = clampedGain
    }

    func setEQPreset(_ preset: EQPreset) {
        for (index, gain) in preset.gains.enumerated() where index < eqFrequencies.count {
            eqGains[index] = min(12, max(-12, gain))
            eqNode.bands[index].gain = eqGains[index]
        }
    }

    deinit {
        if let remoteTimeObserver {
            remotePlayer.removeTimeObserver(remoteTimeObserver)
        }
        if let finishObserver {
            NotificationCenter.default.removeObserver(finishObserver)
        }
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        if let routeChangeObserver { NotificationCenter.default.removeObserver(routeChangeObserver) }
        itemStatusObservation?.invalidate()
        progressTimer?.invalidate()
        playerNode.stop()
        engine.stop()
    }
}
