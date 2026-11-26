//
//  LocalAudioManager.swift
//  AvocadoToast
//
//  Imports individual files and maintains a bookmarked, refreshable music folder.
//

import Foundation
import AVFoundation
import UIKit
import Combine
import CryptoKit

struct ImportedAudio: Sendable {
    let id: String
    let fileURL: URL
    let title: String
    let artist: String
    let duration: Double
    let artworkURL: String?
    let relativePath: String
    let relativeFolderPath: String
}

struct ImportedFolderPlaylist: Sendable {
    let relativeFolderPath: String
    let name: String
    let trackIDs: [String]
}

struct FolderScanResult: Sendable {
    let folderName: String
    let files: [ImportedAudio]
    let playlists: [ImportedFolderPlaylist]
}

@MainActor
final class LocalAudioManager: ObservableObject {
    static let shared = LocalAudioManager()

    private let fileManager = FileManager.default
    private let audioDir: URL
    private let bookmarkKey = "AvocadoToast.linkedMusicFolderBookmark"
    private let folderNameKey = "AvocadoToast.linkedMusicFolderName"

    @Published private(set) var linkedFolderName: String?

    private let allowedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aiff", "aif", "caf", "flac", "alac"
    ]

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioDir = docs.appendingPathComponent("AvocadoToastAudio", isDirectory: true)
        try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        linkedFolderName = UserDefaults.standard.string(forKey: folderNameKey)
    }

    func importAudio(from sourceURL: URL) async throws -> ImportedAudio {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        return try await Self.importAudioFile(
            from: sourceURL,
            into: audioDir,
            relativePath: "manual-import-\(UUID().uuidString)-\(sourceURL.lastPathComponent)",
            relativeFolderPath: ""
        )
    }

    /// Stores a security-scoped bookmark so the folder can be rescanned after relaunch.
    func linkMusicFolder(_ folderURL: URL) throws {
        guard folderURL.isFileURL else { throw LocalAudioImportError.invalidFolder }
        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { folderURL.stopAccessingSecurityScopedResource() } }
        let bookmark = try folderURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        UserDefaults.standard.set(folderURL.lastPathComponent, forKey: folderNameKey)
        linkedFolderName = folderURL.lastPathComponent
    }

    func unlinkMusicFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: folderNameKey)
        linkedFolderName = nil
    }

    func refreshLinkedFolder() async throws -> FolderScanResult {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw LocalAudioImportError.noLinkedFolder
        }
        var stale = false
        let root = try URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        guard root.startAccessingSecurityScopedResource() else {
            throw LocalAudioImportError.folderPermissionExpired
        }
        defer { root.stopAccessingSecurityScopedResource() }

        if stale {
            let renewed = try root.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(renewed, forKey: bookmarkKey)
        }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isHiddenKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw LocalAudioImportError.cannotReadFolder
        }

        var sources: [(url: URL, relativePath: String, relativeFolderPath: String)] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true,
                  allowedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let relative = String(url.path.dropFirst(root.path.hasSuffix("/") ? root.path.count : root.path.count + 1))
            let folder = (relative as NSString).deletingLastPathComponent
            sources.append((url, relative, folder == "." ? "" : folder))
        }

        sources.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        var imported: [ImportedAudio] = []
        for source in sources {
            let item = try await Self.importAudioFile(
                from: source.url,
                into: audioDir,
                relativePath: source.relativePath,
                relativeFolderPath: source.relativeFolderPath
            )
            imported.append(item)
        }

        let grouped = Dictionary(grouping: imported, by: \.relativeFolderPath)
        let playlists = grouped.keys.sorted().compactMap { folderPath -> ImportedFolderPlaylist? in
            guard let items = grouped[folderPath], !items.isEmpty else { return nil }
            let name = folderPath.isEmpty ? root.lastPathComponent : (folderPath as NSString).lastPathComponent
            return ImportedFolderPlaylist(
                relativeFolderPath: folderPath,
                name: name,
                trackIDs: items.map(\.id)
            )
        }

        return FolderScanResult(folderName: root.lastPathComponent, files: imported, playlists: playlists)
    }

    nonisolated private static func importAudioFile(
        from sourceURL: URL,
        into audioDir: URL,
        relativePath: String,
        relativeFolderPath: String
    ) async throws -> ImportedAudio {
        let fileManager = FileManager.default
        let allowedExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "caf", "flac", "alac"]
        let ext = sourceURL.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else { throw LocalAudioImportError.unsupportedFormat }

        let identity = Data(relativePath.utf8)
        let id = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
        let destination = audioDir.appendingPathComponent(id).appendingPathExtension(ext)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)

        do {
            let audioFile = try AVAudioFile(forReading: destination)
            let sampleRate = audioFile.processingFormat.sampleRate
            let duration = sampleRate > 0 ? Double(audioFile.length) / sampleRate : 0
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

            var artworkPath: String?
            if let artworkData, let image = UIImage(data: artworkData),
               let jpegData = image.jpegData(compressionQuality: 0.88) {
                let artworkFile = audioDir.appendingPathComponent("\(id).artwork.jpg")
                try? jpegData.write(to: artworkFile, options: .atomic)
                artworkPath = artworkFile.absoluteString
            }

            return ImportedAudio(
                id: id,
                fileURL: destination,
                title: title,
                artist: artist,
                duration: duration,
                artworkURL: artworkPath,
                relativePath: relativePath,
                relativeFolderPath: relativeFolderPath
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
    case invalidFolder
    case noLinkedFolder
    case folderPermissionExpired
    case cannotReadFolder

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This audio format isn't supported. Try MP3, M4A, AAC, WAV, AIFF, CAF or FLAC."
        case .invalidFolder:
            return "Choose a folder from the Files app."
        case .noLinkedFolder:
            return "No music folder is linked yet."
        case .folderPermissionExpired:
            return "Folder access expired. Link the music folder again."
        case .cannotReadFolder:
            return "The linked folder couldn't be read."
        }
    }
}
