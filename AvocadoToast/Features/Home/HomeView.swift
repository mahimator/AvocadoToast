//
//  HomeView.swift
//  AvocadoToast
//

import SwiftUI

@MainActor
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var library = LibraryService.shared
    @EnvironmentObject private var theme: AppTheme
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    masthead
                    searchLauncher
                    if !library.recentlyPlayed.isEmpty { recentlyPlayedSection }
                    if !viewModel.tracks.isEmpty {
                        featuredSection
                        freshSection
                    } else if viewModel.isLoading {
                        loadingSection
                    } else {
                        emptySection
                    }
                    moodSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadIfNeeded() }
        }
    }

    private var masthead: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AVOCADOTOAST")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2.6)
                    .foregroundStyle(ColorTokens.accentPrimary)
                Text(viewModel.greeting ?? "Good music, good mood.")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Spacer()
            Button { coordinator.selection = .settings } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.12)))
            }
            .accessibilityLabel("Settings")
        }
    }

    private var searchLauncher: some View {
        Button {
            coordinator.searchQuery = ""
            coordinator.selection = .search
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.title3)
                Text("What are you in the mood for?")
                    .font(.subheadline)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Back on the toast", subtitle: "Pick up where you left off")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(library.recentlyPlayed.prefix(12), id: \.id) { track in
                        Button {
                            let item = YouTubeTrack(
                                videoId: track.provider == "local" ? track.id : track.providerID,
                                title: track.title,
                                artist: track.artistName,
                                duration: track.duration,
                                thumbnailURL: track.artworkURL,
                                localFileURL: track.provider == "local" ? track.providerID : nil,
                                provider: track.provider
                            )
                            Task { await CatalogService.shared.playTrack(item) }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: track.artworkURL.flatMap(URL.init(string:)), size: CGSize(width: 128, height: 128)) { image in
                                    if let image {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    } else {
                                        RoundedRectangle(cornerRadius: 16).fill(ColorTokens.artworkPlaceholder)
                                    }
                                }
                                .frame(width: 128, height: 128)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                Text(track.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                                Text(track.artistName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 128, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("On repeat", subtitle: "A little something to start")
            if let featured = viewModel.tracks.first {
                Button {
                    Task { await CatalogService.shared.playTrack(featured) }
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        CachedAsyncImage(url: featured.thumbnailURL.flatMap(URL.init(string:)), size: CGSize(width: 360, height: 230)) { image in
                            if let image {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                ColorTokens.accentPrimary.opacity(0.2)
                            }
                        }
                        .frame(height: 228)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay {
                            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text("FEATURED TRACK")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.8)
                                .foregroundStyle(.white.opacity(0.75))
                            Text(featured.title)
                                .font(.title2.bold())
                                .lineLimit(2)
                            Text(featured.artist)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundStyle(.black)
                                .frame(width: 54, height: 54)
                                .background(ColorTokens.accentPrimary, in: Circle())
                                .padding(18)
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { CatalogService.shared.playNextInQueue(featured) } label: {
                        Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    Button { CatalogService.shared.addToQueue(featured) } label: {
                        Label("Add to queue", systemImage: "text.badge.plus")
                    }
                    Button { CatalogService.shared.toggleSave(featured) } label: {
                        Label(CatalogService.shared.isSaved(featured) ? "Remove from Library" : "Save to Library",
                              systemImage: CatalogService.shared.isSaved(featured) ? "heart.slash" : "heart")
                    }
            }
        }
    }
    }

    private var freshSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Your next obsession", subtitle: "Explore the sound")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.tracks.dropFirst()) { track in
                        Button {
                            Task { await CatalogService.shared.playTrack(track) }
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                CachedAsyncImage(url: track.thumbnailURL.flatMap(URL.init(string:)), size: CGSize(width: 154, height: 154)) { image in
                                    if let image {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    } else {
                                        RoundedRectangle(cornerRadius: 18).fill(ColorTokens.artworkPlaceholder)
                                    }
                                }
                                .frame(width: 154, height: 154)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                Text(track.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 154, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Pick a feeling", subtitle: "Search your own soundtrack")
            HStack(spacing: 10) {
                moodChip("Focus", icon: "brain.head.profile")
                moodChip("Late night", icon: "moon.stars")
                moodChip("Energy", icon: "bolt.fill")
            }
        }
    }

    private func moodChip(_ title: String, icon: String) -> some View {
        Button {
            coordinator.searchQuery = title
            coordinator.selection = .search
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.weight(.bold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var loadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Finding your soundtrack", subtitle: "Loading music from the catalog")
            ProgressView().frame(maxWidth: .infinity, alignment: .leading)
            RoundedRectangle(cornerRadius: 20).fill(.quaternary).frame(height: 180)
        }
    }

    private var emptySection: some View {
        ContentUnavailableView("Nothing queued up", systemImage: "music.note", description: Text("Refresh or search to find your first track."))
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppCoordinator())
        .environmentObject(AppTheme.shared)
}

