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

    private var audioFile: AVAudioFile?
    private var remoteTimeObserver: Any?
    private var finishObserver: NSObjectProtocol?
    private var bufferIsLoaded = false
    private var isRemotePlayback = false
    private var progressTimer: Timer?

    private let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    @Published var eqGains: [Float] = Array(repeating: 0, count: 10)

    private init() {
        setupEngine()
        setupEQ()
        setupRemoteObservers()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
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
            }
        }

        finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      notification.object as? AVPlayerItem === self.remotePlayer.currentItem else { return }
                self.isPlaying = false
                self.currentTime = self.duration
            }
        }
    }

    func play(_ track: YouTubeTrack) async {
        stopPlaybackOnly()
        currentTrack = track
        errorMessage = nil
        currentTime = 0
        duration = 0

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
        let item = AVPlayerItem(url: url)
        remotePlayer.replaceCurrentItem(with: item)
        remotePlayer.play()
        isPlaying = true
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
    }

    func resume() {
        guard currentTrack != nil else { return }
        if isRemotePlayback, remotePlayer.currentItem != nil {
            remotePlayer.play()
            isPlaying = true
        } else if bufferIsLoaded {
            playerNode.play()
            isPlaying = true
            startProgressTimer()
        } else if let currentTrack {
            Task { await play(currentTrack) }
        }
    }

    func stop() {
        stopPlaybackOnly()
        currentTime = 0
        duration = 0
    }

    private func stopPlaybackOnly() {
        remotePlayer.pause()
        remotePlayer.replaceCurrentItem(with: nil)
        playerNode.stop()
        stopProgressTimer()
        isPlaying = false
        bufferIsLoaded = false
        isRemotePlayback = false
        audioFile = nil
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
        progressTimer?.invalidate()
        playerNode.stop()
        engine.stop()
    }
}
