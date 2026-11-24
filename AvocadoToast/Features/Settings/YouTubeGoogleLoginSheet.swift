import SwiftUI
import WebKit
import Combine
import SwiftyTube

@MainActor
final class SignInState: ObservableObject {
    @Published var isCollecting = false
    @Published var message: String?
    @Published var shouldDismiss = false

    func finishSignIn(from webView: WKWebView?) {
        guard let webView else {
            message = "The sign-in page is still opening. Try again in a moment."
            return
        }
        guard !isCollecting else { return }
        isCollecting = true
        message = "Checking your YouTube Music session…"

        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            Task { @MainActor in
                var cookieValues: [String: String] = [:]
                var sapisid: String?
                for cookie in cookies where cookie.domain.lowercased().contains("youtube.com") {
                    cookieValues[cookie.name] = cookie.value
                    if cookie.name == "SAPISID" { sapisid = cookie.value }
                }

                guard !cookieValues.isEmpty, let sapisid, !sapisid.isEmpty else {
                    self.message = "Google sign-in is not complete yet. Finish signing in to YouTube Music, then tap Done."
                    self.isCollecting = false
                    return
                }

                let success = await YouTubeAccountSession.shared.applySession(
                    cookies: cookieValues,
                    sapisid: sapisid
                )
                self.message = YouTubeAccountSession.shared.statusMessage
                self.isCollecting = false
                if success { self.shouldDismiss = true }
            }
        }
    }
}

private struct YouTubeSignInWebView: UIViewRepresentable {
    @Binding var webView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsBackForwardNavigationGestures = true
        // SwiftyTube's cookie-harvest flow expects the desktop YouTube Music
        // sign-in experience and a persistent, app-owned WKWebsiteDataStore.
        view.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView = view
        view.load(URLRequest(url: URL(string: "https://music.youtube.com/")!))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct YouTubeGoogleLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = SignInState()
    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                YouTubeSignInWebView(webView: $webView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let message = state.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                } else {
                    Text("Sign in to your Google account. Your session is saved securely on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
            .navigationTitle("Google Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        state.finishSignIn(from: webView)
                    } label: {
                        if state.isCollecting { ProgressView() } else { Text("Done") }
                    }
                    .disabled(state.isCollecting)
                }
            }
            .onChange(of: state.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss { dismiss() }
            }
        }
    }
}
