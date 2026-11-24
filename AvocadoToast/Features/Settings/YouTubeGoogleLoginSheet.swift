import SwiftUI
import SafariServices
import Combine
import SwiftyTube

struct YouTubeGoogleLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingSafari = false
    @State private var isCollecting = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Sign in to Google")
                    .font(.title2.bold())
                Text("Sign in to YouTube Music below. Your Google cookies will be shared with Safari, so if you're already signed in there, it's automatic.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)

                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }

                Button {
                    isPresentingSafari = true
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
            .sheet(isPresented: $isPresentingSafari) {
                SafariSignInView(
                    onComplete: {
                        isPresentingSafari = false
                        isCollecting = true
                        message = "Harvesting session cookies…"
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            await harvestSession()
                            isCollecting = false
                        }
                    }
                )
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

        guard !cookieDict.isEmpty, let sapisid, !sapisid.isEmpty else {
            self.message = "Couldn't capture a complete session. Make sure you're signed in to YouTube Music, then try again."
            return
        }

        let success = await YouTubeAccountSession.shared.applySession(cookies: cookieDict, sapisid: sapisid)
        self.message = YouTubeAccountSession.shared.statusMessage
    }
}

struct SafariSignInView: UIViewControllerRepresentable {
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: URL(string: "https://music.youtube.com/")!, configuration: config)
        vc.modalPresentationStyle = .pageSheet
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject {
        let onComplete: () -> Void
        init(onComplete: @escaping () -> Void) {
            self.onComplete = onComplete
        }
    }
}

extension SafariSignInView.Coordinator: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        onComplete()
    }
}
