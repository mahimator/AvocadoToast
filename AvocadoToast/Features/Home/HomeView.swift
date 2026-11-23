//
//  HomeView.swift
//  AvocadoToast
//
//  Created by Madhav Trivedi on 20/11/26.
//

import SwiftUI
import Combine

@MainActor
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var theme: AppTheme
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Top area
                    topArea
                    
                    // Search entry
                    searchEntry
                    
                    // Featured tracks
                    if viewModel.tracks.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Featured")
                                .font(.headline.weight(.semibold))
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(viewModel.tracks) { track in
                                        HomeTrackCard(track: track)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .refreshable { await viewModel.refresh() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .background(theme.resolvedBackgroundPrimary.ignoresSafeArea())
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
        }
    }
    
    private var topArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image("app-icon")
                    .renderingMode(.template)
                    .foregroundColor(theme.resolvedAccentPrimary)
                    .frame(width: 32, height: 32)
                Text("Avocado Toast")
                    .font(TextStyle.displayMedium.font)
                    .foregroundColor(theme.resolvedTextPrimary)
            }
            
            if let greeting = viewModel.greeting {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundColor(theme.resolvedTextSecondary)
            }
            
            Spacer()
            
            Button("Settings") { /* Navigate to settings */ }
                .foregroundColor(theme.resolvedTextSecondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(theme.resolvedSurfaceElevated)
                .cornerRadius(20)
        }
    }
    
    private var searchEntry: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundColor(theme.resolvedTextSecondary)
                TextField("Search...", text: .constant(""))
                    .font(.body).foregroundColor(theme.resolvedTextPrimary)
            }
            .hPadding(16).vPadding(14)
            .background(theme.resolvedSurfaceElevated)
            .cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.resolvedSeparator, lineWidth: 1))
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView("Avocado Toast", systemImage: "music.note", description: Text("Search for music to get started"))
    }
}

#Preview {
    HomeView()
        .environmentObject(AppCoordinator())
        .environmentObject(AppTheme.shared)
}

// MARK: - Home track card

struct HomeTrackCard: View {
    let track: YouTubeTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let thumbnailURL = track.thumbnailURL, let url = URL(string: thumbnailURL) {
                CachedAsyncImage(url: url, size: CGSize(width: 150, height: 150)) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }

            Text(track.title)
                .font(.body.weight(.medium))
                .lineLimit(2)
            Text(track.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150)
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 150, height: 150)
    }
}

// MARK: - View extensions

extension View {
    func hPadding(_ length: CGFloat) -> some View { modifier(HPadding(length: length)) }
    func vPadding(_ length: CGFloat) -> some View { modifier(VPadding(length: length)) }
}

struct HPadding: ViewModifier { let length: CGFloat; func body(content: Content) -> some View { content.padding(.horizontal, length) } }
struct VPadding: ViewModifier { let length: CGFloat; func body(content: Content) -> some View { content.padding(.vertical, length) } }
