//
//  AudioPlayerService.swift
//  AvocadoToast
//
//  Real audio playback engine using AVAudioEngine with EQ.
//  Plays YouTube stream URLs and local downloaded files.
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

    @Published var isPlaying = false
    @Published var currentTrack: YouTubeTrack?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?

    private var audioFile: AVAudioFile?
    private var timeObserver: Any?
    private var bufferIsLoaded = false

    private let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    @Published var eqGains: [Float] = Array(repeating: 0, count: 10)

    private init() {
        setupEngine()
        setupEQ()
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.connect(playerNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
        do { try engine.start() } catch { errorMessage = "Engine start failed: \(error.localizedDescription)" }
    }

    private func setupEQ() {
        for (index, freq) in eqFrequencies.enumerated() {
            eqNode.bands[index].frequency = freq
            eqNode.bands[index].gain = 0
            eqNode.bands[index].bypass = false
        }
    }

    func play(_ track: YouTubeTrack) async {
        stop()
        currentTrack = track
        errorMessage = nil

        let url: URL?
        if let localFileURL = track.localFileURL {
            url = URL(fileURLWithPath: localFileURL)
        } else if let streamURL = track.streamURL {
            url = URL(string: streamURL)
        } else {
            errorMessage = "No playable URL for this track"
            return
        }

        guard let url else { errorMessage = "Invalid URL"; return }

        do {
            let asset = AVAsset(url: url)
            let status = try await asset.load(.isPlayable)
            if !status { errorMessage = "Track is not playable"; return }
            audioFile = try AVAudioFile(forReading: url)
            duration = Double(audioFile!.length) / audioFile!.processingFormat.sampleRate
            bufferIsLoaded = true
            playEngine()
        } catch {
            errorMessage = "Failed to load audio: \(error.localizedDescription)"
        }
    }

    private func playEngine() {
        guard bufferIsLoaded, let audioFile else { return }
        playerNode.stop()
        playerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        playerNode.volume = 1.0
        do { try engine.start() } catch { errorMessage = "Engine restart failed: \(error.localizedDescription)"; return }
        playerNode.play()
        isPlaying = true
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
    }

    func resume() {
        playerNode.play()
        isPlaying = true
    }

    func stop() {
        playerNode.stop()
        isPlaying = false
        bufferIsLoaded = false
        audioFile = nil
        currentTime = 0
        duration = 0
    }

    func togglePlayPause() {
        if isPlaying { pause() } else {
            Task { await play(currentTrack ?? YouTubeTrack(videoId: "", title: "", artist: "")) }
        }
    }

    func seek(to time: Double) {
        guard let audioFile else { return }
        let sampleRate = audioFile.processingFormat.sampleRate
        let frame = AVAudioFramePosition(time * sampleRate)
        let frameCount = AVAudioFrameCount(audioFile.length - frame)
        guard frameCount > 0 else { return }
        playerNode.stop()
        playerNode.scheduleSegment(audioFile, startingFrame: frame, frameCount: frameCount, at: nil, completionHandler: nil)
        currentTime = time
        if isPlaying { playerNode.play() }
    }

    func setEQGain(band: Int, gain: Float) {
        guard band >= 0, band < eqFrequencies.count else { return }
        eqGains[band] = gain
        eqNode.bands[band].gain = gain
    }

    func setEQPreset(_ preset: EQPreset) {
        for (index, gain) in preset.gains.enumerated() {
            guard index < eqFrequencies.count else { break }
            eqGains[index] = gain
            eqNode.bands[index].gain = gain
        }
    }

    deinit {
        playerNode.stop()
        engine.stop()
    }
}
