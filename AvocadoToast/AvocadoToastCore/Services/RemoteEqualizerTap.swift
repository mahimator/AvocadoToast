//
//  RemoteEqualizerTap.swift
//  AvocadoToast
//
//  Native real-time EQ for AVPlayer audio tracks. No FFmpeg dependency is
//  required for streams AVPlayer can already decode.
//

import Foundation
import AVFoundation
import AudioToolbox
import MediaToolbox

private struct RemoteEQBiquad {
    let b0: Float
    let b1: Float
    let b2: Float
    let a1: Float
    let a2: Float
}

private final class RemoteEQTapState {
    private let gains: [Float]
    private let enabled: Bool
    private var coefficients: [RemoteEQBiquad] = []
    private var z1: [[Float]] = []
    private var z2: [[Float]] = []
    private var channelCount = 2
    private var isFloat32 = false
    private var isInterleaved = false

    init(gains: [Float], enabled: Bool) {
        self.gains = gains
        self.enabled = enabled
    }

    func prepare(format: AudioStreamBasicDescription) {
        channelCount = max(1, Int(format.mChannelsPerFrame))
        isFloat32 = (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
            && format.mBitsPerChannel == 32
        isInterleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0

        z1 = Array(repeating: Array(repeating: 0, count: gains.count), count: channelCount)
        z2 = Array(repeating: Array(repeating: 0, count: gains.count), count: channelCount)

        guard enabled, format.mSampleRate > 0 else {
            coefficients = []
            return
        }

        let sampleRate = Float(format.mSampleRate)
        let frequencies: [Float] = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        coefficients = frequencies.enumerated().map { index, requestedFrequency in
            let frequency = min(requestedFrequency, sampleRate * 0.45)
            let gain = index < gains.count ? gains[index] : 0
            let amplitude = pow(10, gain / 40)
            let omega = 2 * Float.pi * frequency / sampleRate
            let cosine = cos(omega)
            let alpha = sin(omega) / 2
            let a0 = 1 + alpha / amplitude
            return RemoteEQBiquad(
                b0: (1 + alpha * amplitude) / a0,
                b1: (-2 * cosine) / a0,
                b2: (1 - alpha * amplitude) / a0,
                a1: (-2 * cosine) / a0,
                a2: (1 - alpha / amplitude) / a0
            )
        }
    }

    func process(_ audioBuffers: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) {
        guard enabled, isFloat32, !coefficients.isEmpty, frameCount > 0 else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBuffers)
        var channelOffset = 0

        for buffer in buffers {
            guard let rawData = buffer.mData else {
                channelOffset += Int(buffer.mNumberChannels)
                continue
            }

            let channelsInBuffer = max(1, Int(buffer.mNumberChannels))
            let samples = rawData.assumingMemoryBound(to: Float.self)

            for frame in 0..<frameCount {
                for channel in 0..<channelsInBuffer {
                    let stateChannel = min(channelOffset + channel, channelCount - 1)
                    let sampleIndex = frame * channelsInBuffer + channel
                    var sample = samples[sampleIndex]

                    for band in coefficients.indices {
                        let coefficient = coefficients[band]
                        let output = coefficient.b0 * sample + z1[stateChannel][band]
                        z1[stateChannel][band] = coefficient.b1 * sample
                            - coefficient.a1 * output + z2[stateChannel][band]
                        z2[stateChannel][band] = coefficient.b2 * sample
                            - coefficient.a2 * output
                        sample = output
                    }
                    samples[sampleIndex] = sample
                }
            }

            channelOffset += channelsInBuffer
        }
    }

    func reset() {
        for channel in z1.indices {
            for band in z1[channel].indices {
                z1[channel][band] = 0
                z2[channel][band] = 0
            }
        }
    }
}

private let remoteEQTapInit: MTAudioProcessingTapInitCallback = { _, clientInfo, storageOut in
    storageOut.pointee = clientInfo
}

private let remoteEQTapFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
    Unmanaged<RemoteEQTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
}

private let remoteEQTapPrepare: MTAudioProcessingTapPrepareCallback = { tap, _, processingFormat in
    let state = Unmanaged<RemoteEQTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    state.prepare(format: processingFormat.pointee)
}

private let remoteEQTapUnprepare: MTAudioProcessingTapUnprepareCallback = { tap in
    let state = Unmanaged<RemoteEQTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    state.reset()
}

private let remoteEQTapProcess: MTAudioProcessingTapProcessCallback = {
    tap, requestedFrames, _, bufferList, framesOut, flagsOut in

    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        requestedFrames,
        bufferList,
        flagsOut,
        nil,
        framesOut
    )
    guard status == noErr else {
        framesOut.pointee = 0
        return
    }

    let state = Unmanaged<RemoteEQTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    state.process(bufferList, frameCount: Int(framesOut.pointee))
}

enum RemoteEqualizerTap {
    static func makeAudioMix(
        for track: AVAssetTrack,
        gains: [Float],
        enabled: Bool
    ) throws -> AVAudioMix {
        let state = RemoteEQTapState(gains: gains, enabled: enabled)
        let retainedState = Unmanaged.passRetained(state)

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: retainedState.toOpaque(),
            init: remoteEQTapInit,
            finalize: remoteEQTapFinalize,
            prepare: remoteEQTapPrepare,
            unprepare: remoteEQTapUnprepare,
            process: remoteEQTapProcess
        )

        var unmanagedTap: Unmanaged<MTAudioProcessingTap>?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &unmanagedTap
        )

        guard status == noErr, let unmanagedTap else {
            retainedState.release()
            throw NSError(
                domain: "AvocadoToast.RemoteEqualizerTap",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Could not create the remote audio equalizer."]
            )
        }

        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.audioTapProcessor = unmanagedTap.takeRetainedValue()

        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        return mix
    }
}
