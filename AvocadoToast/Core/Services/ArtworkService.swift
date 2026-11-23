//
//  ArtworkService.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import Foundation
import Combine
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Artwork loading service with memory + disk cache.
/// - Asynchronous, non-blocking loading
/// - Memory cache (NSCache) with bounded size
/// - Disk cache in Application Support directory
/// - Placeholder handling for invalid/unavailable artwork
@MainActor
final class ArtworkService: ObservableObject {
    static let shared = ArtworkService()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.avocadotoast.artwork", qos: .userInitiated)
    private let maxMemoryCount = 100
    private let colorContext = CIContext(options: [.cacheIntermediates: false])
    private var colorCache: [String: UIColor] = [:]

    private init() {
        memoryCache.countLimit = maxMemoryCount
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        diskCacheURL = appSupport?.appendingPathComponent("ArtworkCache", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true, attributes: nil)
    }

    // MARK: - Public API

    /// Load artwork asynchronously. Returns a cached image instantly when
    /// available, otherwise downloads and caches it.
    func loadArtwork(from url: URL, size: CGSize = CGSize(width: 300, height: 300)) async -> UIImage? {
        // 1. Memory cache
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return resize(cached, to: size)
        }

        // 2. Disk cache
        if let diskImage = loadFromDisk(url: url) {
            memoryCache.setObject(diskImage, forKey: url as NSURL)
            return resize(diskImage, to: size)
        }

        // 3. Download
        guard let image = await download(url: url) else { return nil }

        // Cache (memory + disk) off the actor
        memoryCache.setObject(image, forKey: url as NSURL)
        saveToDisk(image: image, url: url)

        return resize(image, to: size)
    }

    /// Synchronous memory-cache lookup (useful for scrollable lists).
    func imageInMemory(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    /// Returns a softly sampled average artwork colour for ambient player styling.
    /// Average colour is intentionally used instead of a complex palette extractor:
    /// it is cheap, stable, and can be safely blended into the player backdrop.
    func ambientColor(from url: URL) async -> Color? {
        let key = url.absoluteString
        if let cached = colorCache[key] { return Color(cached) }
        guard let image = await loadArtwork(from: url, size: CGSize(width: 64, height: 64)),
              let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let output = filter.outputImage,
              let pixel = colorContext.createCGImage(output, from: CGRect(x: 0, y: 0, width: 1, height: 1)),
              let data = pixel.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let color = UIColor(
            red: CGFloat(bytes[0]) / 255,
            green: CGFloat(bytes[1]) / 255,
            blue: CGFloat(bytes[2]) / 255,
            alpha: 1
        )
        colorCache[key] = color
        if colorCache.count > 100 { colorCache.removeValue(forKey: colorCache.keys.first ?? key) }
        return Color(color)
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true, attributes: nil)
    }

    // MARK: - Private

    private func download(url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  !data.isEmpty,
                  let image = UIImage(data: data) else { return nil }
            return image
        } catch {
            return nil
        }
    }

    private func diskFileURL(for url: URL) -> URL {
        let filename = url.absoluteString
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return diskCacheURL.appendingPathComponent(filename)
    }

    private func loadFromDisk(url: URL) -> UIImage? {
        let fileURL = diskFileURL(for: url)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    private func saveToDisk(image: UIImage, url: URL) {
        guard let data = image.pngData() else { return }
        let fileURL = diskFileURL(for: url)
        queue.async {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - SwiftUI image loading view modifier placeholder

import SwiftUI

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let size: CGSize
    @ViewBuilder let content: (UIImage?) -> Content

    @State private var image: UIImage?
    @State private var isLoaded = false

    var body: some View {
        Group {
            if let image {
                content(image)
            } else {
                content(nil)
            }
        }
        .task {
            guard let url, !isLoaded else { return }
            image = await ArtworkService.shared.loadArtwork(from: url, size: size)
            isLoaded = true
        }
    }
}
