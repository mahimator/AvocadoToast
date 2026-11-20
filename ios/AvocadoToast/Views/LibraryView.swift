import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Your library starts here", systemImage: "books.vertical",
                description: Text("Saved tracks and playlists will appear here."))
                .background(Color.black.ignoresSafeArea()).navigationTitle("Library")
        }
    }
}