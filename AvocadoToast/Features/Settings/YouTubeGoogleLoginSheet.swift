import SwiftUI
import AuthenticationServices
import SwiftyTube

final class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}

struct YouTubeGoogleLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isCollecting = false
    @State private var message: String?
    @State private var authSession: ASWebAuthenticationSession?
    @State private var presentationProvider = AuthPresentationProvider()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Sign in to Google")
                    .font(.title2.bold())
                Text("Sign in to YouTube Music below. Avocado Toast will use your YouTube session for your personal playlists and account library.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)

                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }

                Button {
                    signIn()
                } label: {
                    if isCollecting { ProgressView().frame(maxWidth: .infinity) }
                    else { Text("Sign in with Google").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCollecting)
                .padding(.horizontal)
                .padding(.bottom, 8)

                Text("If you're already signed into Google in Safari, your account will be detected automatically.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            .navigationTitle("Google Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func signIn() {
        isCollecting = true
        message = "Opening Google sign-in…"

        let url = URL(string: "https://music.youtube.com/")!
        let callbackURLScheme = "avocadotoast"

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { callbackURL, error in
            Task { @MainActor in
                self.isCollecting = false

                if let error {
                    self.message = nil
                    self.harvestSession()
                    return
                }

                self.harvestSession()
            }
        }

        authSession?.presentationContextProvider = presentationProvider
        authSession?.start()
    }

    private func harvestSession() {
        message = "Harvesting session cookies…"

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            let cookies = HTTPCookieStorage.shared.cookies ?? []
            let youtubeCookies = cookies.filter { cookie in
                cookie.domain.contains("youtube.com") || cookie.domain.contains("google.com")
            }

            var cookieDict: [String: String] = [:]
            var sapisid: String?
            var visitorData: String?

            for cookie in youtubeCookies {
                cookieDict[cookie.name] = cookie.value
                if cookie.name == "SAPISID" { sapisid = cookie.value }
                if cookie.name == "Visitor-Data" { visitorData = cookie.value }
            }

            guard !cookieDict.isEmpty, let sapisid, !sapisid.isEmpty else {
                self.message = "Couldn't capture a complete session. Make sure you're signed in to YouTube Music, then try again."
                return
            }

            let success = await YouTubeAccountSession.shared.applySession(cookies: cookieDict, sapisid: sapisid)
            self.message = YouTubeAccountSession.shared.statusMessage
            if success { self.dismiss() }
        }
    }
}
