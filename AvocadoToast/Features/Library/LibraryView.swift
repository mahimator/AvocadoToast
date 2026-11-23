//
//  LibraryView.swift
//  AvocadoToast
//
//  Library: a quiet, warm place for the things you keep.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @StateObject private var library = LibraryService.shared
    @State private var selectedFilter: LibraryFilter = .songs
    @State private var showingNewPlaylist = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                header
                filterPicker
                    .padding(.horizontal, 18)

                if libraryIsEmpty {
                    emptyState
                } else {
                    listView
                }
            }
            .padding(.top, 8)
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewPlaylist) {
                NewPlaylistView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear { library.refresh() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("THE PANTRY")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(ColorTokens.accentPrimary)
                Text("Your Library")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            Spacer()
            Button { showingNewPlaylist = true } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(ColorTokens.separator))
            }
            .accessibilityLabel("Create playlist")
        }
        .padding(.horizontal, 20)
    }

    private var filterPicker: some View {
        Picker("Library filter", selection: $selectedFilter) {
            ForEach(LibraryFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var libraryIsEmpty: Bool {
        switch selectedFilter {
        case .songs: library.savedTracks.isEmpty
        case .albums: library.savedAlbums.isEmpty
        case .artists: library.savedArtists.isEmpty
        case .playlists: library.savedPlaylists.isEmpty
        case .recent: library.recentlyPlayed.isEmpty
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: selectedFilter.emptyIcon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(ColorTokens.accentPrimary)
                .frame(width: 84, height: 84)
                .background(ColorTokens.surfaceGlass, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            Text(selectedFilter.emptyTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ColorTokens.textPrimary)
            Text(selectedFilter.emptyDescription)
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            if selectedFilter == .playlists {
                Button { showingNewPlaylist = true } label: {
                    Label("Make a playlist", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(ColorTokens.accentPrimary, in: Capsule())
                        .foregroundStyle(ColorTokens.backgroundPrimary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    @ViewBuilder
    private var listView: some View {
        List {
            switch selectedFilter {
            case .songs:
                ForEach(library.savedTracks, id: \.id) { track in
                    LibraryRow(title: track.title, subtitle: track.artistName,
                               artworkURL: track.artworkURL.flatMap(URL.init(string:)))
                        .contextMenu {
                            Button(role: .destructive) { library.removeTrack(track) } label: {
                                Label("Remove from library", systemImage: "trash")
                            }
                        }
                }
            case .albums:
                ForEach(library.savedAlbums, id: \.id) { album in
                    LibraryRow(title: album.title, subtitle: album.artistName,
                               artworkURL: album.artworkURL.flatMap(URL.init(string:)))
                }
            case .artists:
                ForEach(library.savedArtists, id: \.id) { artist in
                    LibraryRow(title: artist.name, subtitle: artist.genres.joined(separator: ", "),
                               artworkURL: artist.artworkURL.flatMap(URL.init(string:)))
                }
            case .playlists:
                ForEach(library.savedPlaylists, id: \.id) { playlist in
                    LibraryRow(title: playlist.name, subtitle: "\(playlist.trackIDs.count) tracks",
                               artworkURL: playlist.artworkURL.flatMap(URL.init(string:)))
                        .contextMenu {
                            Button(role: .destructive) { library.deletePlaylist(playlist) } label: {
                                Label("Delete playlist", systemImage: "trash")
                            }
                        }
                }
            case .recent:
                ForEach(library.recentlyPlayed, id: \.id) { track in
                    LibraryRow(title: track.title, subtitle: track.artistName,
                               artworkURL: track.artworkURL.flatMap(URL.init(string:)))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.backgroundPrimary)
    }
}

struct LibraryRow: View {
    let title: String
    let subtitle: String
    let artworkURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                Text(subtitle.isEmpty ? "A little something you saved" : subtitle)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 6)
        .listRowBackground(ColorTokens.backgroundSecondary)
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkURL {
            CachedAsyncImage(url: artworkURL, size: CGSize(width: 54, height: 54)) { image in
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    placeholderArtwork
                }
            }
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(ColorTokens.surfaceElevated)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(width: 54, height: 54)
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case songs, albums, artists, playlists, recent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .songs: return "Songs"
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .playlists: return "Playlists"
        case .recent: return "Recent"
        }
    }
    var emptyIcon: String {
        switch self {
        case .songs: return "music.note"
        case .albums: return "square.stack"
        case .artists: return "person.crop.circle"
        case .playlists: return "music.note.list"
        case .recent: return "clock"
        }
    }
    var emptyTitle: String {
        switch self {
        case .songs: return "Nothing on the toast yet"
        case .albums: return "No albums tucked away"
        case .artists: return "No artists in your pantry"
        case .playlists: return "The pantry is empty"
        case .recent: return "Nothing playing lately"
        }
    }
    var emptyDescription: String {
        switch self {
        case .songs: return "Save tracks you want to come back to."
        case .albums: return "Keep the albums you love close."
        case .artists: return "Save artists to keep them within reach."
        case .playlists: return "Make a little collection for every mood."
        case .recent: return "Play a little music and your history will show up here."
        }
    }
}

struct NewPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("A new little collection") {
                    TextField("Playlist name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        LibraryService.shared.createPlaylist(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: description.isEmpty ? nil : description
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
