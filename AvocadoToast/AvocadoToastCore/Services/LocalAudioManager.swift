//
//  LocalAudioManager.swift
//  AvocadoToast
//
//  Manages downloading YouTube audio streams to local storage for offline playback.
//

import Foundation
import Combine

@MainActor
final class LocalAudioManager: ObservableObject {
    static let shared = LocalAudioManager()

    private let fileManager = FileManager.default

    @Published var downloadingIDs: Set<String> = []

    private let audioDir: URL

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioDir = docs.appendingPathComponent("AvocadoToastAudio", isDirectory: true)
        try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true, attributes: nil)
    }

    private func localFileURL(for videoId: String) -> URL {
        audioDir.appendingPathComponent("\(videoId).m4a")
    }

    func localFilePath(for videoId: String) -> String? {
        let url = localFileURL(for: videoId)
        return fileManager.fileExists(atPath: url.path) ? url.path : nil
    }

    func isDownloaded(videoId: String) -> Bool {
        fileManager.fileExists(atPath: localFileURL(for: videoId).path)
    }

    func download(_ track: YouTubeTrack, streamURL: String) async {
        guard !downloadingIDs.contains(track.videoId) else { return }
        downloadingIDs.insert(track.videoId)
        defer { downloadingIDs.remove(track.videoId) }

        let fileURL = localFileURL(for: track.videoId)

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: URL(string: streamURL)!)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return
            }

            try fileManager.moveItem(at: tempURL, to: fileURL)
        } catch {
            print("Download error: \(error.localizedDescription)")
        }
    }

    func cancelDownload(videoId: String) {
        downloadingIDs.remove(videoId)
    }

    func deleteLocalFile(videoId: String) {
        let url = localFileURL(for: videoId)
        try? fileManager.removeItem(at: url)
    }
}
