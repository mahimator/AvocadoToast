import SwiftUI
import WebKit
import Combine
import SwiftyTube

struct YouTubeGoogleLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingWebView = false
    @State private var isCollecting = false
    @State private var message: String?
    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Sign in to Google")
                    .font(.title2.bold())
                Text("Sign in to YouTube Music below. Your session cookies will be saved securely on this device.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)

                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }

                Button {
                    isPresentingWebView = true
                } label: {
                    if isCollecting { ProgressView().frame(maxWidth: .infinity) }
                    else { Text("Sign in with Google").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCollecting)
                .padding(.horizontal)
                .padding(.bottom, 8)

                Text("Passkeys, Face ID, and saved Safari passwords are supported.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            .navigationTitle("Google Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $isPresentingWebView) {
                NavigationStack {
                    VStack(spacing: 0) {
                        HStack {
                            Button("Done") {
                                isPresentingWebView = false
                                isCollecting = true
                                message = "Harvesting session cookies…"
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    await harvestSession()
                                    isCollecting = false
                                }
                            }
                            .font(.headline)
                            Spacer()
                            Button("Cancel") {
                                isPresentingWebView = false
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.thinMaterial)

                        GoogleLoginWebView(webView: $webView)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .presentationDetents([.large])
            }
            .onChange(of: message) { _, newValue in
                if let newValue, newValue.hasPrefix("Signed in") {
                    dismiss()
                }
            }
        }
    }

    private func harvestSession() async {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let youtubeCookies = cookies.filter { cookie in
            cookie.domain.contains("youtube.com") || cookie.domain.contains("google.com")
        }

        var cookieDict: [String: String] = [:]
        var sapisid: String?

        for cookie in youtubeCookies {
            cookieDict[cookie.name] = cookie.value
            if cookie.name == "SAPISID" { sapisid = cookie.value }
        }

        DiagnosticLogger.shared.write("LOGIN harvested cookies=\(cookieDict.count) sapisid=\(sapisid != nil ? "yes" : "no")")

        guard !cookieDict.isEmpty, let sapisid, !sapisid.isEmpty else {
            self.message = "Couldn't capture a complete session. Make sure you're signed in to YouTube Music, then try again."
            return
        }

        let success = await YouTubeAccountSession.shared.applySession(cookies: cookieDict, sapisid: sapisid)
        self.message = YouTubeAccountSession.shared.statusMessage
        DiagnosticLogger.shared.write("LOGIN applySession success=\(success) message=\(YouTubeAccountSession.shared.statusMessage ?? "nil")")
    }
}

struct GoogleLoginWebView: UIViewRepresentable {
    @Binding var webView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = context.coordinator
        webView = view
        view.load(URLRequest(url: URL(string: "https://music.youtube.com/")!))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DiagnosticLogger.shared.write("WEBVIEW didFinish url=\(webView.url?.absoluteString ?? "nil")")
        }
    }
}
