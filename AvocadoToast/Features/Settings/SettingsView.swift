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
                Button("Delete saved music and playlists", role: .destructive) { resetLibrary() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes locally saved tracks, albums, artists, playlists, and listening history. This cannot be undone.")
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
            try modelContext.fetch(FetchDescriptor<TrackModel>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<AlbumModel>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<ArtistModel>()).forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<PlaylistModel>()).forEach(modelContext.delete)
            try modelContext.save()
            LibraryService.shared.refresh()
            resetMessage = "Your local library has been cleared."
        } catch {
            resetMessage = "Could not clear the library: \(error.localizedDescription)"
        }
    }
}
