import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerStore
    var body: some View {
        Group {
            if let track = player.currentTrack {
                HStack(spacing: 12) {
                    Image(systemName: "waveform").foregroundStyle(.mint).frame(width: 38, height: 38)
                        .background(.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(track.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { player.togglePlayback() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3).foregroundStyle(.white)
                    }.accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                }.padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12).padding(.bottom, 6)
            }
        }
    }
}