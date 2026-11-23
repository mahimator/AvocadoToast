//
//  SettingsView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI

/// Settings screen: appearance, motion, library, cache, backend and about.
/// All controls bind directly to AppConfig.shared so changes persist immediately.
struct SettingsView: View {
    @ObservedObject private var config = AppConfig.shared
    @State private var backendURLString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $config.selectedAppearance) {
                        ForEach(AppConfig.Appearance.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Reduce Motion", isOn: $config.reduceMotion)
                    Toggle("Glass Effects", isOn: $config.enableGlassEffects)
                }

                Section("Library") {
                    Button("Clear Cache") { ArtworkService.shared.clearCache() }
                    Button("Reset Library") { /* reset handled via persistence */ }
                }

                Section("Backend") {
                    TextField("Backend URL (e.g. http://192.168.1.50:8000)", text: $backendURLString)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.done)
                        .onSubmit {
                            if let url = URL(string: backendURLString), url.scheme != nil {
                                config.backendURL = url
                            }
                        }
                    Text("On iPhone, enter your Mac's local IP (e.g. http://192.168.1.50:8000)")
                        .font(.caption2)
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
                    HStack {
                        Text("Current URL")
                        Spacer()
                        Text(config.backendURL.absoluteString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                backendURLString = config.backendURL.absoluteString
            }
        }
    }
}
