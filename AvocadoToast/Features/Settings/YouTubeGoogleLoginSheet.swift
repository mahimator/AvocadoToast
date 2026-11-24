import SwiftUI
import AuthenticationServices
import Combine
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

@MainActor
final class SignInState: ObservableObject {
    @Published var isCollecting = false
    @Published var message: String?
    @Published var shouldDismiss = false
    var authSession: ASWebAuthenticationSession?
    private let presentationProvider = AuthPresentationProvider()

    func signInInApp() {
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
                    self.harvestSession()
                }
            }
        }

        authSession?.presentationContextProvider = presentationProvider
        authSession?.start()
    }

    func importFromSafari() {
        isCollecting = true
        message = "Checking Safari cookies…"
        harvestSession()
    }

    private func harvestSession() {
        Task {
            // Give cookies time to be written to shared storage
            try? await Task.sleep(nanoseconds: 1_000_000_000)

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
                self.message = "No YouTube session found in Safari. Sign in to music.youtube.com in Safari first, then try again."
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
            VStack(spacing: 16) {
                Text("Sign in to Google")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 12) {
                    Text("Option 1: Sign in here (passkeys supported)")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        state.signInInApp()
                    } label: {
                        if state.isCollecting { ProgressView() }
                        else { Text("Open Google Sign-In").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.isCollecting)

                    Text("Uses the system sign-in view. Passkeys, Face ID, and saved Safari passwords work here.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                Divider().padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Option 2: Import from Safari")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        state.importFromSafari()
                    } label: {
                        if state.isCollecting { ProgressView() }
                        else { Text("Import Safari Session").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(state.isCollecting)

                    Text("Sign in to music.youtube.com in Safari first, then tap this to import your session.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                if let message = state.message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                Spacer(minLength: 20)
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
