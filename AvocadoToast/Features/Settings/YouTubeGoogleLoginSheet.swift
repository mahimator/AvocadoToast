import SwiftUI
import Combine
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

/// Manages Google sign-in state so the ASWebAuthenticationSession completion
/// handler can mutate it (structs can't be captured weakly in closures).
@MainActor
final class SignInState: ObservableObject {
    @Published var isCollecting = false
    @Published var message: String?
    @Published var shouldDismiss = false
    var authSession: ASWebAuthenticationSession?
    private let presentationProvider = AuthPresentationProvider()

    func signIn() {
        isCollecting = true
        message = "Opening Google sign-in…"

        let url = URL(string: "https://music.youtube.com/")!

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: nil
        ) { _, error in
            Task { @MainActor in
                self.isCollecting = false
                if let error {
                    self.message = "Sign-in was cancelled."
                } else {
                    // Session completed — automatically harvest cookies
                    self.harvestSession()
                }
            }
        }

        authSession?.presentationContextProvider = presentationProvider
        authSession?.start()
    }

    func harvestSession() {
        message = "Harvesting session cookies…"

        Task {
            // Give cookies time to be written to shared storage
            try? await Task.sleep(nanoseconds: 1_500_000_000)

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
                self.isCollecting = false
                return
            }

            let success = await YouTubeAccountSession.shared.applySession(cookies: cookieDict, sapisid: sapisid)
            self.message = YouTubeAccountSession.shared.statusMessage
            self.isCollecting = false
            if success {
                self.shouldDismiss = true
            }
        }
    }
}

struct YouTubeGoogleLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = SignInState()
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Sign in to Google")
                    .font(.title2.bold())
                Text("Sign in to YouTube Music below. Your Google cookies will be shared with Safari, so if you're already signed in there, it's automatic.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)

                if let message = state.message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }

                Button {
                    state.signIn()
                } label: {
                    if state.isCollecting { ProgressView().frame(maxWidth: .infinity) }
                    else { Text("Sign in with Google").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isCollecting)
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
            .onChange(of: state.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
        }
    }
}
