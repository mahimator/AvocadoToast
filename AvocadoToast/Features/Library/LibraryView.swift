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
    @ObservedObject private var accountSession = YouTubeAccountSession.shared
    @ObservedObject private var localAudioManager = LocalAudioManager.shared
    @ObservedObject private var config = AppConfig.shared
    @State private var selectedFilter: LibraryFilter = .songs
    @State private var showingNewPlaylist = false
    @State private var showingAudioImporter = false
    @State private var showingFolderImporter = false
    @State private var isRefreshingLinkedFolder = false
    @State private var importError: String?
    @State private var isImportingAudio = false
    @State private var importProgress = 0.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                header
                linkedFolderBar
                if isImportingAudio { importProgressView }
                if library.isSyncingYouTubeLibrary {
                    ProgressView("Syncing your YouTube Music library…")
                        .font(.footnote)
                        .padding(.horizontal, 20)
                } else if let syncError = library.youtubeLibraryError {
                    Text("YouTube Music library couldn't refresh: \(syncError)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }

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
            .fileImporter(
                isPresented: $showingFolderImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let folder = urls.first else { return }
                    do {
                        try localAudioManager.linkMusicFolder(folder)
                        refreshLinkedFolder()
                    } catch {
                        importError = error.localizedDescription
                    }
                case .failure(let error):
                    importError = error.localizedDescription
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
            .task {
                library.refresh()
                if localAudioManager.linkedFolderName != nil {
                    refreshLinkedFolder(showResult: false)
                }
                if accountSession.isSignedIn {
                    await library.syncYouTubeLibrary()
                    CatalogService.shared.refreshSavedTracks()
                }
            }
            .onChange(of: accountSession.isSignedIn) { _, signedIn in
                if signedIn {
                    Task {
                        await library.syncYouTubeLibrary()
                        CatalogService.shared.refreshSavedTracks()
                    }
                }
            }
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
                .disabled(isImportingAudio || isRefreshingLinkedFolder)
                Button {
                    showingFolderImporter = true
                } label: {
                    Label("Link a music folder", systemImage: "folder.badge.plus")
                }
                .disabled(isImportingAudio || isRefreshingLinkedFolder)
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(config.enableGlassEffects ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(ColorTokens.backgroundSecondary), in: Circle())
                    .overlay(Circle().strokeBorder(ColorTokens.separator))
            }
            .accessibilityLabel("Add to library")
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var linkedFolderBar: some View {
        if let folderName = localAudioManager.linkedFolderName {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(ColorTokens.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folderName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("Linked music folder")
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                Spacer()
                Button {
                    refreshLinkedFolder()
                } label: {
                    if isRefreshingLinkedFolder {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .disabled(isRefreshingLinkedFolder || isImportingAudio)
                .accessibilityLabel("Refresh linked music folder")
                Menu {
                    Button("Choose another folder", systemImage: "folder.badge.plus") {
                        showingFolderImporter = true
                    }
                    Button("Unlink folder", systemImage: "link.badge.minus", role: .destructive) {
                        localAudioManager.unlinkMusicFolder()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(config.enableGlassEffects ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(ColorTokens.backgroundSecondary), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(ColorTokens.separator))
            .padding(.horizontal, 20)
        }
    }

    private func refreshLinkedFolder(showResult: Bool = true) {
        guard !isRefreshingLinkedFolder else { return }
        isRefreshingLinkedFolder = true
        Task { @MainActor in
            defer { isRefreshingLinkedFolder = false }
            do {
                let result = try await localAudioManager.refreshLinkedFolder()
                library.importFolderScan(result)
                CatalogService.shared.refreshSavedTracks()
                let summary = "Found \(result.files.count) audio files and updated \(result.playlists.count) folder playlists."
                if showResult {
                    importError = result.failures.isEmpty
                        ? summary
                        : summary + "\n\nSkipped \(result.failures.count) file(s):\n" + result.failures.prefix(8).joined(separator: "\n")
                }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func importAudioFiles(_ urls: [URL]) {
        guard !urls.isEmpty, !isImportingAudio else { return }
        Task { await importAudioFilesAsync(urls) }
    }

    private func importAudioFilesAsync(_ urls: [URL]) async {
        isImportingAudio = true
        importProgress = 0
        defer {
            isImportingAudio = false
            importProgress = 0
        }

        var failedImports: [String] = []
        var importedModels: [TrackModel] = []
        for (index, source) in urls.enumerated() {
            do {
                let imported = try await LocalAudioManager.shared.importAudio(from: source)
                let model = TrackModel(
                    id: imported.id,
                    provider: "local",
                    providerID: imported.fileURL.path,
                    title: imported.title,
                    artistName: imported.artist,
                    artworkURL: imported.artworkURL,
                    duration: imported.duration,
                    isVideo: false,
                    isPlayable: true,
                    addedAt: Date(),
                    playCount: 0
                )
                importedModels.append(model)
            } catch {
                failedImports.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
            importProgress = Double(index + 1) / Double(urls.count)
        }

        library.saveTracks(importedModels)
        CatalogService.shared.refreshSavedTracks()
        let importedCount = importedModels.count
        if failedImports.isEmpty {
            importError = "Imported \(importedCount) audio file\(importedCount == 1 ? "" : "s") into your library."
        } else {
            importError = "Imported \(importedCount) file\(importedCount == 1 ? "" : "s").\n\n" + failedImports.joined(separator: "\n")
        }
    }

    private var importProgressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Adding music to your pantry")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(importProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            ProgressView(value: importProgress)
                .tint(ColorTokens.accentPrimary)
        }
        .padding(.horizontal, 20)
    }
    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedFilter == filter ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background(
                                selectedFilter == filter ? ColorTokens.accentMuted : (config.enableGlassEffects ? ColorTokens.surfaceGlass : ColorTokens.backgroundSecondary),
                                in: Capsule()
                            )
                            .overlay(Capsule().strokeBorder(ColorTokens.separator))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
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
            AvocadoMascotView(mood: selectedFilter == .songs ? .emptyToaster : .importing)
                .padding(.bottom, 2)
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
                        AlbumDetailView(query: album.providerID.isEmpty ? album.title : album.providerID)
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
                        ArtistDetailView(query: artist.providerID.isEmpty ? artist.name : artist.providerID)
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
                        if playlist.provider == "youtube" {
                            PlaylistDetailView(playlistID: playlist.providerID)
                        } else {
                            LocalPlaylistDetailView(playlist: playlist)
                        }
                    } label: {
                        LibraryRow(title: playlist.name,
                                  subtitle: playlist.provider == "youtube" ? (playlist.metadata["trackCount"] ?? "Playlist") : "\(playlist.trackIDs.count) tracks",
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
                provider: model.provider,
                isVideo: model.isVideo
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
                    .onMove { offsets, destination in
                        library.moveTrackInPlaylist(playlist, from: offsets, to: destination)
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
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
