//
//  DiagnosticLogger.swift
//  AvocadoToast
//
//  Writes diagnostic events to a file in the Documents directory so they can
//  be copied off the device for debugging.
//

import Foundation

@MainActor
final class DiagnosticLogger {
    static let shared = DiagnosticLogger()

    private let logURL: URL
    private let queue = DispatchQueue(label: "com.avocadotoast.diagnostics", qos: .utility)

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logURL = docs.appendingPathComponent("AvocadoToastDiagnostics.log")
        write("=== Avocado Toast Diagnostics Started ===")
    }

    func write(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        queue.async {
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logURL.path) {
                    if let handle = try? FileHandle(forWritingTo: self.logURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: self.logURL, options: .atomic)
                }
            }
        }
    }

    func logSearch(term: String, type: String, client: String, resultCount: Int, error: String?) {
        write("SEARCH term='\(term)' type='\(type)' client='\(client)' results=\(resultCount) error=\(error ?? "none")")
    }

    func logStream(videoId: String, attempt: Int, client: String, success: Bool, error: String?) {
        write("STREAM videoId='\(videoId)' attempt=\(attempt) client='\(client)' success=\(success) error=\(error ?? "none")")
    }

    func logHome(success: Bool, trackCount: Int, error: String?) {
        write("HOME success=\(success) tracks=\(trackCount) error=\(error ?? "none")")
    }

    func logSession(signedIn: Bool, accountName: String?) {
        write("SESSION signedIn=\(signedIn) account=\(accountName ?? "nil")")
    }

    func contents() -> String? {
        try? String(contentsOf: logURL, encoding: .utf8)
    }
}
