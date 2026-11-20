import Foundation
import SwiftUI

@MainActor
final class PlayerStore: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying = false

    // Replace this boundary with a playback provider licensed for the intended use.
    // ytmusicapi supplies catalog metadata; it is not a native playback SDK.
    func select(_ track: Track) { currentTrack = track; isPlaying = false }
    func togglePlayback() { isPlaying.toggle() }
}