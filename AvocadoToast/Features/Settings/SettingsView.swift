//
//  SettingsView.swift
//  AvocadoToast
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @ObservedObject private var config = AppConfig.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingResetConfirmation = false
    @State private var resetMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $config.selectedAppearance) {
                        ForEach(AppConfig.Appearance.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Artwork ambience", isOn: $config.artworkBackgroundEnabled)
                    Toggle("Reduce Motion", isOn: $config.reduceMotion)
                    Toggle("Glass Effects", isOn: $config.enableGlassEffects)
                }
                Section("Storage") {
                    Button("Clear artwork cache", systemImage: "photo") {
                        ArtworkService.shared.clearCache()
                    }
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset local library", systemImage: "trash")
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Catalog", value: "YouTube Music")
                    LabeledContent("Architecture", value: "Native iPhone app")
                    Text("Your library and preferences stay on this device. Catalog availability depends on the provider.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete your local library?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Delete library and imported audio", role: .destructive) { resetLibrary() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes saved tracks, albums, artists, playlists, listening history, and imported audio files. This cannot be undone.")
            }
            .alert("Library", isPresented: Binding(get: { resetMessage != nil }, set: { if !$0 { resetMessage = nil } })) {
                Button("OK", role: .cancel) { resetMessage = nil }
            } message: {
                Text(resetMessage ?? "")
            }
        }
    }

    private func resetLibrary() {
        do {
            for item in try modelContext.fetch(FetchDescriptor<TrackModel>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<AlbumModel>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<ArtistModel>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<PlaylistModel>()) { modelContext.delete(item) }
            for item in try modelContext.fetch(FetchDescriptor<RecentTrackModel>()) { modelContext.delete(item) }
            try modelContext.save()
            if AudioPlayerService.shared.currentTrack?.provider == "local" {
                CatalogService.shared.stop()
            }
            LocalAudioManager.shared.clearImportedAudio()
            LibraryService.shared.refresh()
            CatalogService.shared.refreshSavedTracks()
            resetMessage = "Your local library has been cleared."
        } catch {
            resetMessage = "Could not clear the library: \(error.localizedDescription)"
        }
    }
}
