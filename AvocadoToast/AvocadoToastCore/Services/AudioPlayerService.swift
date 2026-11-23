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


    private init() {
        setupEngine()
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
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
        } catch {
            errorMessage = "Audio engine start failed: \(error.localizedDescription)"
        }
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
