import SwiftUI
import WebKit
import SwiftyTube

struct YouTubeGoogleLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var webView: WKWebView?
    @State private var isCollecting = false
    @State private var message: String?
    @State private var collectTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Sign in to Google")
                    .font(.title2.bold())
                Text("Sign in to YouTube Music in the browser below. Avocado Toast will use your YouTube session for your personal playlists and account library.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
                GoogleLoginWebView(webView: $webView)
                    .ignoresSafeArea(edges: .bottom)
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                Button {
                    collectSession()
                } label: {
                    if isCollecting { ProgressView().frame(maxWidth: .infinity) }
                    else { Text("I've signed in, continue").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCollecting || webView == nil)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Google Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { collectTask?.cancel(); dismiss() } }
            }
        }
        .onDisappear { collectTask?.cancel() }
    }

    private func collectSession() {
        guard let webView else { return }
        isCollecting = true
        message = "Waiting for your YouTube session to finish..."
        collectTask = Task {
            let session = await LoginWebviewHarvest.collectSession(from: webView, maxAttempts: 25)
            guard !Task.isCancelled else { return }
            guard let session else {
                isCollecting = false
                message = "Couldn't capture a complete session. Make sure you're signed in and YouTube Music is open, then try again."
                return
            }
            let success = await YouTubeAccountSession.shared.applySession(cookies: session.cookies, sapisid: session.sapisid)
            isCollecting = false
            message = YouTubeAccountSession.shared.statusMessage
            if success { dismiss() }
        }
    }
}

private struct GoogleLoginWebView: UIViewRepresentable {
    @Binding var webView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.customUserAgent = LoginWebviewHarvest.userAgent
        view.allowsBackForwardNavigationGestures = true
        webView = view
        view.load(URLRequest(url: URL(string: "https://music.youtube.com/")!))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
