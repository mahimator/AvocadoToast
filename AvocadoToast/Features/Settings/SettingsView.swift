//
//  SettingsView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI

/// Settings screen: appearance, motion, library, cache, backend and about.
struct SettingsView: View {
    @AppStorage("backendURL") private var backendURLString: String = ""
    @State private var appearance: AppConfig.Appearance = .dark
    @State private var reduceMotion: Bool = false
    @State private var enableGlass: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppConfig.Appearance.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Reduce Motion", isOn: $reduceMotion)
                    Toggle("Glass Effects", isOn: $enableGlass)
                }

                Section("Library") {
                    Button("Clear Cache") { ArtworkService.shared.clearCache() }
                    Button("Reset Library") { /* reset handled via persistence */ }
                }

                Section("Backend") {
                    TextField("Backend URL", text: $backendURLString)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Text("Changes apply on next launch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Backend")
                        Spacer()
                        Text("FastAPI + ytmusicapi").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
