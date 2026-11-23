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
                    
                    // Sections
                    if viewModel.sections.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.sections) { section in
                            SectionView(section: section)
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
        .environmentObject(AppTheme())
}

extension View {
    func hPadding(_ length: CGFloat) -> some View { modifier(HPadding(length: length)) }
    func vPadding(_ length: CGFloat) -> some View { modifier(VPadding(length: length)) }
}

struct HPadding: ViewModifier { let length: CGFloat; func body(content: Content) -> some View { content.padding(.horizontal, length) } }
struct VPadding: ViewModifier { let length: CGFloat; func body(content: Content) -> some View { content.padding(.vertical, length) } }