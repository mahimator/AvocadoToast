//
//  LocalAudioManager.swift
//  AvocadoToast
//
//  Owns user-imported audio files. The app copies files into its sandbox and
//  never downloads catalog audio for offline playback.
//

import Foundation
import AVFoundation
import UIKit
import Combine

struct ImportedAudio {
    let id: String
    let fileURL: URL
    let title: String
    let artist: String
    let duration: Double
    let artworkURL: String?
}

@MainActor
final class LocalAudioManager: ObservableObject {
    static let shared = LocalAudioManager()

    private let fileManager = FileManager.default
    private let audioDir: URL

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioDir = docs.appendingPathComponent("AvocadoToastAudio", isDirectory: true)
        try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true, attributes: nil)
    }

    func importAudio(from sourceURL: URL) async throws -> ImportedAudio {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        let destinationDirectory = audioDir
        return try await Task.detached(priority: .userInitiated) {
            try Self.importAudioFile(from: sourceURL, into: destinationDirectory)
        }.value
    }

    nonisolated private static func importAudioFile(from sourceURL: URL, into audioDir: URL) throws -> ImportedAudio {
        let fileManager = FileManager.default
        let allowedExtensions = ["mp3", "m4a", "aac", "wav", "aiff", "caf"]
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else {
            throw LocalAudioImportError.unsupportedFormat
        }

        let id = UUID().uuidString
        let destination = audioDir.appendingPathComponent(id).appendingPathExtension(fileExtension)
        try fileManager.copyItem(at: sourceURL, to: destination)

        do {
            let audioFile = try AVAudioFile(forReading: destination)
            let duration = audioFile.processingFormat.sampleRate > 0
                ? Double(audioFile.length) / audioFile.processingFormat.sampleRate
                : 0
            let asset = AVURLAsset(url: destination)
            let metadata = asset.commonMetadata
            let title = AVMetadataItem.metadataItems(
                from: metadata,
                withKey: AVMetadataKey.commonKeyTitle,
                keySpace: .common
            ).first?.stringValue ?? sourceURL.deletingPathExtension().lastPathComponent
            let artist = AVMetadataItem.metadataItems(
                from: metadata,
                withKey: AVMetadataKey.commonKeyArtist,
                keySpace: .common
            ).first?.stringValue ?? "Unknown Artist"
            let artworkData = AVMetadataItem.metadataItems(
                from: metadata,
                withKey: AVMetadataKey.commonKeyArtwork,
                keySpace: .common
            ).first?.dataValue
            let artworkPath: String?
            if let artworkData, let image = UIImage(data: artworkData),
               let jpegData = image.jpegData(compressionQuality: 0.9) {
                let artworkFile = audioDir.appendingPathComponent("\(id).artwork").appendingPathExtension("jpg")
                do {
                    try jpegData.write(to: artworkFile, options: .atomic)
                    artworkPath = artworkFile.absoluteString
                } catch {
                    artworkPath = nil
                }
            } else {
                artworkPath = nil
            }
            return ImportedAudio(
                id: id,
                fileURL: destination,
                title: title,
                artist: artist,
                duration: duration,
                artworkURL: artworkPath
            )
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
    }
    func deleteImportedAudio(at path: String) {
        let root = audioDir.standardizedFileURL.path + "/"
        let candidate = URL(fileURLWithPath: path).standardizedFileURL
        guard candidate.path.hasPrefix(root) else { return }
        try? fileManager.removeItem(at: candidate)
        let artwork = audioDir.appendingPathComponent(candidate.deletingPathExtension().lastPathComponent + ".artwork.jpg")
        try? fileManager.removeItem(at: artwork)
    }

    func clearImportedAudio() {
        guard let files = try? fileManager.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) else { return }
        for file in files { try? fileManager.removeItem(at: file) }
    }
}

enum LocalAudioImportError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This audio format isn't supported. Try MP3, M4A, AAC, WAV, AIFF or CAF."
        }
    }
}
