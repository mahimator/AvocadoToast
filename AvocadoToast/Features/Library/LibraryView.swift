//
//  LibraryView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import SwiftData

/// Library screen: saved tracks, albums, artists, playlists and recently played.
/// Persists via SwiftData and survives application restarts.
struct LibraryView: View {
    @StateObject private var library = LibraryService.shared
    @Environment(\.modelContext) private var modelContext

    @State private var selectedFilter: LibraryFilter = .songs
    @State private var showingNewPlaylist = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPicker
                    .padding(.horizontal)

                if libraryIsEmpty {
                    emptyState
                } else {
                    listView
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingNewPlaylist = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Playlist")
                }
            }
            .sheet(isPresented: $showingNewPlaylist) {
                NewPlaylistView()
            }
        }
    }

    // MARK: - Subviews

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(LibraryFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var libraryIsEmpty: Bool {
        switch selectedFilter {
        case .songs: return library.savedTracks.isEmpty
        case .albums: return library.savedAlbums.isEmpty
        case .artists: return library.savedArtists.isEmpty
        case .playlists: return library.savedPlaylists.isEmpty
        case .recent: return library.recentlyPlayed.isEmpty
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Library is empty",
            systemImage: "music.note",
            description: Text("Save tracks, albums, artists or playlists to build your library")
        )
    }

    private var listView: some View {
        List {
            switch selectedFilter {
            case .songs:
                ForEach(Array(library.savedTracks.enumerated()), id: \.element.id) { _, track in
                    LibraryRow(title: track.title, subtitle: track.artistName,
                               artworkURL: track.artworkURL.flatMap { URL(string: $0) })
                    .contextMenu {
                        Button(action: { library.removeTrack(track) }) {
                            Text("Remove from Library")
                        }
                    }
                }
            case .albums:
                ForEach(Array(library.savedAlbums.enumerated()), id: \.element.id) { _, album in
                    LibraryRow(title: album.title, subtitle: album.artistName,
                               artworkURL: album.artworkURL.flatMap { URL(string: $0) })
                }
            case .artists:
                ForEach(Array(library.savedArtists.enumerated()), id: \.element.id) { _, artist in
                    LibraryRow(title: artist.name, subtitle: artist.genres.joined(separator: ", "),
                               artworkURL: artist.artworkURL.flatMap { URL(string: $0) })
                }
            case .playlists:
                ForEach(Array(library.savedPlaylists.enumerated()), id: \.element.id) { _, playlist in
                    LibraryRow(title: playlist.name, subtitle: "\(playlist.trackIDs.count) tracks",
                               artworkURL: playlist.artworkURL.flatMap { URL(string: $0) })
                }
            case .recent:
                ForEach(Array(library.recentlyPlayed.enumerated()), id: \.element.id) { _, track in
                    LibraryRow(title: track.title, subtitle: track.artistName,
                               artworkURL: track.artworkURL.flatMap { URL(string: $0) })
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Library row

struct LibraryRow: View {
    let title: String
    let subtitle: String
    let artworkURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            if let artworkURL {
                CachedAsyncImage(url: artworkURL, size: CGSize(width: 52, height: 52)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Library filter

enum LibraryFilter: String, CaseIterable, Identifiable {
    case songs = "songs"
    case albums = "albums"
    case artists = "artists"
    case playlists = "playlists"
    case recent = "recent"

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
}

// MARK: - New playlist view

struct NewPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Playlist") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        LibraryService.shared.createPlaylist(name: name, description: description.isEmpty ? nil : description)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
