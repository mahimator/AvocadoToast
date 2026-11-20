import SwiftUI

struct TrackRow: View {
    let track: Track
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10).fill(.mint.opacity(0.16)).frame(width: 54, height: 54)
                .overlay { Image(systemName: "music.note").font(.title2).foregroundStyle(.mint) }
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let duration = track.duration {
                Text(duration).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
    }
}