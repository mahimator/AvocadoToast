//
//  LibraryView.swift
//  AvocadoToast
//
//  Library: a quiet, warm place for the things you keep.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var library = LibraryService.shared
    @State private var selectedFilter: LibraryFilter = .songs
    @State private var showingNewPlaylist = false
    @State private var showingAudioImporter = false
    @State private var importError: String?

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
            .fileImporter(
                isPresented: $showingAudioImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls): importAudioFiles(urls)
                case .failure(let error): importError = error.localizedDescription
                }
            }
            .alert("Audio import", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
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
            Menu {
                Button {
                    showingNewPlaylist = true
                } label: {
                    Label("Create playlist", systemImage: "music.note.list")
                }
                Button {
                    showingAudioImporter = true
                } label: {
                    Label("Import audio files", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(ColorTokens.separator))
            }
            .accessibilityLabel("Add to library")
        }
        .padding(.horizontal, 20)
    }

    private func importAudioFiles(_ urls: [URL]) {
        var failedImports: [String] = []
        for source in urls {
            do {
                let imported = try LocalAudioManager.shared.importAudio(from: source)
                let model = TrackModel(
                    id: imported.id,
                    provider: "local",
                    providerID: imported.fileURL.path,
                    title: imported.title,
                    artistName: imported.artist,
                    artworkURL: nil,
                    duration: imported.duration,
                    isVideo: false,
                    isPlayable: true,
                    addedAt: Date(),
                    playCount: 0
                )
                library.saveTrack(model)
            } catch {
                failedImports.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if !failedImports.isEmpty {
            importError = failedImports.joined(separator: "\n")
        }
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
                               artworkURL: track.artworkURL.flatMap(URL.init(string:)),
                               onTap: { playSavedTrack(track) })
                        .contextMenu {
                            Button(role: .destructive) { library.removeTrack(track) } label: {
                                Label("Remove from library", systemImage: "trash")
                            }
                        }
                }
            case .albums:
                ForEach(library.savedAlbums, id: \.id) { album in
                    NavigationLink {
                        AlbumDetailView(query: album.title)
                    } label: {
                        LibraryRow(title: album.title, subtitle: album.artistName,
                                  artworkURL: album.artworkURL.flatMap(URL.init(string:)))
                    }
                    .contextMenu {
                        Button(role: .destructive) { library.removeAlbum(album) } label: {
                            Label("Remove album", systemImage: "trash")
                        }
                    }
                }
            case .artists:
                ForEach(library.savedArtists, id: \.id) { artist in
                    NavigationLink {
                        ArtistDetailView(query: artist.name)
                    } label: {
                        LibraryRow(title: artist.name, subtitle: artist.genres.joined(separator: ", "),
                                  artworkURL: artist.artworkURL.flatMap(URL.init(string:)))
                    }
                    .contextMenu {
                        Button(role: .destructive) { library.removeArtist(artist) } label: {
                            Label("Remove artist", systemImage: "trash")
                        }
                    }
                }
            case .playlists:
                ForEach(library.savedPlaylists, id: \.id) { playlist in
                    NavigationLink {
                        LocalPlaylistDetailView(playlist: playlist)
                    } label: {
                        LibraryRow(title: playlist.name, subtitle: "\(playlist.trackIDs.count) tracks",
                                  artworkURL: playlist.artworkURL.flatMap(URL.init(string:)))
                    }
                    .contextMenu {
                            Button(role: .destructive) { library.deletePlaylist(playlist) } label: {
                                Label("Delete playlist", systemImage: "trash")
                            }
                        }
                }
            case .recent:
                ForEach(library.recentlyPlayed, id: \.id) { track in
                    LibraryRow(title: track.title, subtitle: track.artistName,
                               artworkURL: track.artworkURL.flatMap(URL.init(string:)),
                               onTap: { playRecentTrack(track) })
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
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            Button(action: onTap) { rowContent }
                .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
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
        .contentShape(Rectangle())
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

// MARK: - Library playback

private extension LibraryView {
    func playRecentTrack(_ model: RecentTrackModel) {
        let track = YouTubeTrack(
            videoId: model.provider == "local" ? model.id : model.providerID,
            title: model.title,
            artist: model.artistName,
            duration: model.duration,
            thumbnailURL: model.artworkURL,
            localFileURL: model.provider == "local" ? model.providerID : nil,
            provider: model.provider
        )
        Task { await CatalogService.shared.playTrack(track) }
    }
    func playSavedTrack(_ model: TrackModel) {
        let track = YouTubeTrack(
            videoId: model.provider == "local" ? model.id : (model.providerID.isEmpty ? model.id : model.providerID),
            title: model.title,
            artist: model.artistName,
            duration: model.duration ?? 0,
            thumbnailURL: model.artworkURL,
            localFileURL: model.provider == "local" ? model.providerID : nil,
            provider: model.provider
        )
        Task { await CatalogService.shared.playTrack(track) }
    }
}

// MARK: - Local playlist detail

private struct LocalPlaylistDetailView: View {
    let playlist: PlaylistModel
    @ObservedObject private var library = LibraryService.shared
    @State private var showingAddTracks = false
    @State private var showingRename = false
    @State private var newName = ""

    private var tracks: [TrackModel] {
        playlist.trackIDs.compactMap { id in
            library.savedTracks.first(where: { $0.id == id })
        }
    }

    private var queueTracks: [YouTubeTrack] {
        tracks.compactMap { model in
            guard model.provider == "youtube" || model.provider == "local" else { return nil }
            return YouTubeTrack(
                videoId: model.provider == "local" ? model.id : (model.providerID.isEmpty ? model.id : model.providerID),
                title: model.title,
                artist: model.artistName,
                duration: model.duration ?? 0,
                thumbnailURL: model.artworkURL,
                localFileURL: model.provider == "local" ? model.providerID : nil,
                provider: model.provider
            )
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(playlist.name)
                        .font(.title2.bold())
                    Text("\(tracks.count) saved songs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button {
                            Task { await CatalogService.shared.playQueue(queueTracks) }
                        } label: {
                            Label("Play playlist", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(queueTracks.isEmpty)
                        Button {
                            showingAddTracks = true
                        } label: {
                            Label("Add songs", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }
            Section("Songs") {
                if tracks.isEmpty {
                    ContentUnavailableView("This playlist is empty", systemImage: "music.note.list", description: Text("Add songs you've saved in your library."))
                } else {
                    ForEach(tracks, id: \.id) { track in
                        LibraryRow(
                            title: track.title,
                            subtitle: track.artistName,
                            artworkURL: track.artworkURL.flatMap(URL.init(string:)),
                            onTap: {
                                guard let index = queueTracks.firstIndex(where: { $0.videoId == track.id || $0.videoId == track.providerID }) else { return }
                                Task { await CatalogService.shared.playQueue(queueTracks, startAt: index) }
                            }
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                library.removeTrackFromPlaylist(playlist, trackId: track.id)
                            } label: {
                                Label("Remove from playlist", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rename") {
                    newName = playlist.name
                    showingRename = true
                }
            }
        }
        .sheet(isPresented: $showingAddTracks) {
            PlaylistTrackPicker(playlist: playlist)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Rename playlist", isPresented: $showingRename) {
            TextField("Playlist name", text: $newName)
            Button("Save") {
                let cleaned = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { library.renamePlaylist(playlist, to: cleaned) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct PlaylistTrackPicker: View {
    let playlist: PlaylistModel
    @ObservedObject private var library = LibraryService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(library.savedTracks, id: \.id) { track in
                    Button {
                        library.addTrackToPlaylist(playlist, track: track)
                    } label: {
                        HStack(spacing: 12) {
                            LibraryRow(title: track.title, subtitle: track.artistName, artworkURL: track.artworkURL.flatMap(URL.init(string:)))
                            if playlist.trackIDs.contains(track.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ColorTokens.accentPrimary)
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(playlist.trackIDs.contains(track.id))
                }
            }
            .navigationTitle("Add songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
