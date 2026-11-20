import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: PlayerStore
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let api = MusicAPI(baseURL: AppConfig.apiBaseURL)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Songs, artists, albums", text: $query)
                        .submitLabel(.search).onSubmit { Task { await search() } }
                    if !query.isEmpty {
                        Button { query = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }.padding(14).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                if isLoading { ProgressView("Searching…") }
                else if let errorMessage {
                    ContentUnavailableView("Couldn't search", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if results.isEmpty {
                    ContentUnavailableView("Find your next repeat", systemImage: "music.note",
                        description: Text("Search the catalog by song, artist, or album."))
                } else {
                    List(results) { track in
                        TrackRow(track: track).listRowBackground(Color.clear)
                            .contentShape(Rectangle()).onTapGesture { player.select(track) }
                    }.listStyle(.plain)
                }
                Spacer(minLength: 0)
            }.padding(20).background(Color.black.ignoresSafeArea())
                .navigationTitle("Search").safeAreaInset(edge: .bottom) { MiniPlayerView() }
        }
    }

    @MainActor
    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { results = try await api.searchTracks(query: term) }
        catch { errorMessage = "Check that the AvocadoToast backend is running and reachable." }
    }
}