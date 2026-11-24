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
                Text("Sign in to YouTube Music below. Your Google cookies will be shared with Safari, so if you're already signed in there, it's automatic.")
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

                if authSession != nil {
                    Button("I've signed in, continue") {
                        finishSignIn()
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                Text("Passkeys, Face ID, and saved passwords in Safari are supported.")
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
        // No callbackURLScheme — YouTube Music doesn't redirect back to our app.
        // The user signs in, then taps "I've signed in, continue" to harvest cookies.
        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: nil
        ) { _, error in
            Task { @MainActor in
                self.isCollecting = false
                if let error {
                    self.message = "Sign-in was cancelled."
                }
            }
        }

        authSession?.presentationContextProvider = presentationProvider
        authSession?.start()
    }

    private func finishSignIn() {
        isCollecting = true
        message = "Harvesting session cookies…"

        // Cancel the session now that the user has finished signing in
        authSession?.cancel()
        authSession = nil

        Task {
            // Give cookies time to be written to shared storage
            try? await Task.sleep(nanoseconds: 1_500_000_000)

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
                self.isCollecting = false
                return
            }

            let success = await YouTubeAccountSession.shared.applySession(cookies: cookieDict, sapisid: sapisid)
            self.message = YouTubeAccountSession.shared.statusMessage
            self.isCollecting = false
            if success { self.dismiss() }
        }
    }
}
