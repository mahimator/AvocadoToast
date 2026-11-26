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
    private let equalizer = AVAudioUnitEQ(numberOfBands: 10)
    private let remotePlayer = AVPlayer()

    static let equalizerFrequencies: [Float] = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    @Published var equalizerEnabled: Bool = UserDefaults.standard.object(forKey: "AvocadoToast.eq.enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(equalizerEnabled, forKey: "AvocadoToast.eq.enabled")
            applyEqualizerSettings()
        }
    }
    @Published var equalizerGains: [Float] = {
        let stored = UserDefaults.standard.array(forKey: "AvocadoToast.eq.gains") as? [NSNumber]
        return stored?.map(\.floatValue) ?? Array(repeating: 0, count: 10)
    }() {
        didSet {
            UserDefaults.standard.set(equalizerGains.map(NSNumber.init(value:)), forKey: "AvocadoToast.eq.gains")
            applyEqualizerSettings()
        }
    }

    @Published var isPlaying = false
    @Published var currentTrack: YouTubeTrack?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackNext: (() -> Void)?
    var onPlaybackPrevious: (() -> Void)?
    var onPlaybackRetry: (() -> Void)?

    private var audioFile: AVAudioFile?
    private var remoteTimeObserver: Any?
    private var finishObserver: NSObjectProtocol?
    private var bufferIsLoaded = false
    private var isRemotePlayback = false
    private var progressTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var shouldResumeAfterInterruption = false

    var videoPlayer: AVPlayer { remotePlayer }
    var isUsingRemotePlayer: Bool { isRemotePlayback }

    func setEqualizerGain(_ gain: Float, at index: Int) {
        guard equalizerGains.indices.contains(index) else { return }
        var updated = equalizerGains
        updated[index] = min(12, max(-12, gain))
        equalizerGains = updated
    }

    private func applyEqualizerSettings() {
        guard equalizer.bands.count == Self.equalizerFrequencies.count else { return }
        for index in equalizer.bands.indices {
            let band = equalizer.bands[index]
            band.filterType = .parametric
            band.frequency = Self.equalizerFrequencies[index]
            band.bandwidth = 1.0
            band.gain = equalizerGains.indices.contains(index) ? equalizerGains[index] : 0
            band.bypass = !equalizerEnabled
        }
        equalizer.bypass = !equalizerEnabled
    }

    private init() {
        setupEngine()
        setupRemoteObservers()
        configureRemoteCommands()
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
            setupSessionObservers(session)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
            DiagnosticLogger.shared.write("AUDIO_SESSION setup failed: \(error.localizedDescription)")
        }
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(equalizer)
        engine.connect(playerNode, to: equalizer, format: nil)
        engine.connect(equalizer, to: engine.mainMixerNode, format: nil)
        applyEqualizerSettings()
        do {
            try engine.start()
        } catch {
            errorMessage = "Audio engine start failed: \(error.localizedDescription)"
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

    // MARK: - Public playback

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
            DiagnosticLogger.shared.write("PLAYBACK no valid streamURL for track='\(track.videoId)'")
            return
        }

        playRemoteURL(url)
    }

    // MARK: - Local file playback

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

    // MARK: - Remote URL playback

    private func playRemoteURL(_ url: URL) {
        isRemotePlayback = true
        bufferIsLoaded = false
        audioFile = nil
        playerNode.stop()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        // YouTube stream URLs require proper HTTP headers (User-Agent, client headers)
        // otherwise AVPlayer returns "Cannot Open". Use AVURLAsset with header options.
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
                "X-YouTube-Client-Name": "5",
                "X-YouTube-Client-Version": "21.26.4",
                "X-YouTube-Device": "1",
                "Accept-Language": "en-US,en;q=0.9",
                "Referer": "https://www.youtube.com/"
            ]
        ])
        let item = AVPlayerItem(asset: asset)
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] (item: AVPlayerItem, _) in
            Task { @MainActor in
                guard let self, self.remotePlayer.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    let itemDuration = item.duration.seconds
                    if itemDuration.isFinite && itemDuration > 0 { self.duration = itemDuration }
                    self.remotePlayer.play()
                    self.isPlaying = self.remotePlayer.timeControlStatus == .playing
                    self.errorMessage = nil
                    self.updateNowPlayingInfo()
                    DiagnosticLogger.shared.write("PLAYBACK readyToPlay track='\(self.currentTrack?.videoId ?? "nil")' isPlaying=\(self.isPlaying) duration=\(self.duration)")
                case .failed:
                    self.errorMessage = item.error?.localizedDescription ?? "This audio source couldn't be played."
                    self.isPlaying = false
                    self.updateNowPlayingInfo()
                    DiagnosticLogger.shared.write("PLAYBACK failed track='\(self.currentTrack?.videoId ?? "nil")' error=\(item.error?.localizedDescription ?? "unknown")")
                default:
                    break
                }
            }
        }
        remotePlayer.allowsExternalPlayback = true
        remotePlayer.replaceCurrentItem(with: item)
        isPlaying = false
        updateNowPlayingInfo()
    }

    // MARK: - Local engine playback

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

    // MARK: - Playback control

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
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Audio session couldn't resume: \(error.localizedDescription)"
            return
        }
        if isRemotePlayback, let item = remotePlayer.currentItem {
            if item.status == .failed {
                if let onPlaybackRetry {
                    onPlaybackRetry()
                } else if let currentTrack {
                    Task { await play(currentTrack) }
                }
                return
            }
            remotePlayer.play()
            isPlaying = true
            updateNowPlayingInfo()
        } else if bufferIsLoaded {
            do {
                if !engine.isRunning { try engine.start() }
            } catch {
                errorMessage = "Audio engine couldn't resume: \(error.localizedDescription)"
                return
            }
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
            let trackID = currentTrack?.videoId
            playerNode.scheduleSegment(audioFile, startingFrame: frame, frameCount: count, at: nil) { [weak self] in
                Task { @MainActor in
                    guard let self, self.currentTrack?.videoId == trackID, !self.isRemotePlayback else { return }
                    self.isPlaying = false
                    self.currentTime = self.duration
                    self.stopProgressTimer()
                    self.updateNowPlayingInfo()
                    self.onPlaybackFinished?()
                }
            }
            currentTime = target
            if isPlaying { playerNode.play() }
            updateLocalPlaybackTime()
        }
    }

    // MARK: - Progress timer

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

    // MARK: - Now Playing

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
