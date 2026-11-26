//
//  LocalAudioManagerTests.swift
//  AvocadoToastTests
//
//  Phase 3 · Local library · Imports (MP3/M4A/multiple/unsupported/malformed) → Deletion
//

import AVFoundation
import Foundation
import XCTest

@MainActor
final class LocalAudioManagerTests: XCTestCase {
    let manager = LocalAudioManager.shared

    override func tearDown() {
        // Clean any test audio left in the sandbox.
        manager.clearImportedAudio()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a short silent audio file for the given extension in a temp directory.
    private func makeTestAudioFile(ext: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("audio").appendingPathExtension(ext)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100.0,
            AVEncoderBitRateKey: 128000,
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let fileType: AVFileType = (ext == "m4a" || ext == "aac") ? .m4a : .mp3
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount: UInt32 = 4410 // ~0.1 s of silence
        let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        pcm.frameLength = frameCount

        let timing = CMSampleTimingInfo(
            duration: CMTime(value: Int64(frameCount), timescale: 44100),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .zero
        )
        var formatDesc: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: pcm.format.streamDescription,
            layoutSize: 0,
            layout: nil,
            magicNumberSize: 0,
            magicNumber: nil,
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )
        var sbuf: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc!,
            sampleCount: Int(pcm.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sbuf
        )
        input.append(sbuf!)
        input.markAsFinished()
        writer.finishWriting {}

        return url
    }

    func testImportMP3() async throws {
        let url = try makeTestAudioFile(ext: "mp3")
        let imported = try await manager.importAudio(from: url)
        XCTAssertEqual(imported.id.count, 64)
        XCTAssertFalse(imported.title.isEmpty)
        XCTAssertEqual(imported.artist, "Unknown Artist")
        XCTAssertGreaterThan(imported.duration, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.fileURL.path))
        manager.deleteImportedAudio(at: imported.fileURL.path)
    }

    func testImportM4A() async throws {
        let url = try makeTestAudioFile(ext: "m4a")
        let imported = try await manager.importAudio(from: url)
        XCTAssertFalse(imported.title.isEmpty)
        XCTAssertGreaterThan(imported.duration, 0)
        manager.deleteImportedAudio(at: imported.fileURL.path)
    }

    func testImportMultipleFiles() async throws {
        let urls = try (0..<3).map { _ in try makeTestAudioFile(ext: "m4a") }
        var count = 0
        for url in urls {
            let _ = try await manager.importAudio(from: url)
            count += 1
        }
        XCTAssertEqual(count, 3)
        manager.clearImportedAudio()
    }

    func testImportUnsupportedFormatThrows() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("song").appendingPathExtension("txt")
        try! "not audio".data(using: .utf8)!.write(to: url)

        do {
            _ = try await manager.importAudio(from: url)
            XCTFail("Unsupported files should be rejected")
        } catch {
            XCTAssertEqual(error as? LocalAudioImportError, LocalAudioImportError.unsupportedFormat)
        }
    }

    func testImportMalformedFileThrows() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("broken").appendingPathExtension("m4a")
        try! Data([0x00, 0x01, 0x02, 0x03]).write(to: url)

        do {
            _ = try await manager.importAudio(from: url)
            XCTFail("Malformed audio should be rejected")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testDeleteAndClearImportedAudio() async throws {
        let url = try makeTestAudioFile(ext: "m4a")
        let imported = try await manager.importAudio(from: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.fileURL.path))

        manager.deleteImportedAudio(at: imported.fileURL.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imported.fileURL.path))

        let url2 = try makeTestAudioFile(ext: "m4a")
        let _ = try await manager.importAudio(from: url2)
        manager.clearImportedAudio()
        XCTAssertFalse(FileManager.default.fileExists(atPath: imported.fileURL.path))
    }
}
