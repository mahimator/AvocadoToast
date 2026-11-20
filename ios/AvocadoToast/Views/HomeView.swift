import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var player: PlayerStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR SOUND,").font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(3).foregroundStyle(.mint)
                        Text("uninterrupted.").font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles").font(.title2).foregroundStyle(.mint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("A fresh start").font(.headline)
                            Text("Search the YouTube Music catalog and build your own library.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                    Text("QUICK PICKS").font(.caption.bold()).tracking(2).foregroundStyle(.secondary)
                    TrackRow(track: .preview).contentShape(Rectangle())
                        .onTapGesture { player.select(.preview) }
                }.padding(20)
            }.background(Color.black.ignoresSafeArea())
                .navigationTitle("AvocadoToast").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) { MiniPlayerView() }
        }
    }
}