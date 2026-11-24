import Foundation
import Combine
import Security
import SwiftyTube

@MainActor
final class YouTubeAccountSession: ObservableObject, AuthStateProvider {
    static let shared = YouTubeAccountSession()
    @Published private(set) var account: AccountInfo?
    @Published private(set) var isSignedIn = false
    @Published private(set) var isWorking = false
    @Published var statusMessage: String?
    private let key = "AvocadoToast.YouTube.AuthState"

    private init() {
        isSignedIn = loadSavedAuth() != nil
    }

    func cookies() async -> [String: String] { loadSavedAuth()?.cookies ?? [:] }
    func sapisid() async -> String? { loadSavedAuth()?.sapisid }
    func visitorData() async -> String? { loadSavedAuth()?.visitorData }
    func dataSyncId() async -> String? { loadSavedAuth()?.dataSyncId }

    func applySession(cookies: [String: String], sapisid: String?) async -> Bool {
        guard !cookies.isEmpty, let sapisid, !sapisid.isEmpty else {
            statusMessage = "Google sign-in did not return a complete YouTube session. Try again."
            return false
        }
        let auth = AuthState(cookies: cookies, sapisid: sapisid, visitorData: cookies["visitor_data"])
        do {
            let data = try JSONEncoder().encode(auth)
            guard keychainWrite(data) else {
                statusMessage = "Couldn't securely save your sign-in on this device."
                return false
            }
            await YouTubeKitService.shared.loadSavedSession()
            let info = try await YouTubeKitService.shared.fetchAccountInfo()
            guard info.name != "Guest", !info.name.isEmpty else {
                keychainDelete()
                await YouTubeKitService.shared.useGuestSession()
                isSignedIn = false
                account = nil
                statusMessage = "YouTube did not accept this session. Please sign in again."
                return false
            }
            account = info
            isSignedIn = true
            statusMessage = "Signed in as \(info.name)"
            DiagnosticLogger.shared.logSession(signedIn: true, accountName: info.name)
            return true
        } catch {
            // Keep the newly harvested cookies. Account verification can fail
            // temporarily because of network or InnerTube availability.
            isSignedIn = true
            account = nil
            DiagnosticLogger.shared.logSession(signedIn: true, accountName: nil)
            statusMessage = "Session saved. Account verification is temporarily unavailable: \(error.localizedDescription)"
            return true
        }
    }

    func restore() async {
        guard loadSavedAuth() != nil else {
            isSignedIn = false
            account = nil
            DiagnosticLogger.shared.logSession(signedIn: false, accountName: nil)
            return
        }
        isWorking = true
        defer { isWorking = false }
        await YouTubeKitService.shared.loadSavedSession()
        do {
            let info = try await YouTubeKitService.shared.fetchAccountInfo()
            if info.name != "Guest" && !info.name.isEmpty {
                account = info
                isSignedIn = true
                statusMessage = nil
            } else {
                keychainDelete()
                account = nil
                isSignedIn = false
                await YouTubeKitService.shared.useGuestSession()
                DiagnosticLogger.shared.logSession(signedIn: false, accountName: nil)
                statusMessage = "Saved Google session expired. Sign in again."
            }
        } catch {
            // Do not destroy a persisted session because a transient request
            // failed. Keep the credentials loaded so the next API request can
            // retry without sending the user through Google sign-in again.
            account = nil
            isSignedIn = loadSavedAuth() != nil
            DiagnosticLogger.shared.logSession(signedIn: isSignedIn, accountName: nil)
            statusMessage = "Saved session couldn't be checked right now. We'll keep it and retry automatically."
        }
    }

    func signOut() async {
        keychainDelete()
        account = nil
        isSignedIn = false
        statusMessage = "Signed out. Using guest catalog."
        await YouTubeKitService.shared.useGuestSession()
        DiagnosticLogger.shared.logSession(signedIn: false, accountName: nil)
    }

    private func loadSavedAuth() -> AuthState? {
        guard let data = keychainRead() else { return nil }
        return try? JSONDecoder().decode(AuthState.self, from: data)
    }

    private func keychainRead() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "AvocadoToast.YouTubeSession",
            kSecAttrAccount as String: key, kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func keychainWrite(_ data: Data) -> Bool {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "AvocadoToast.YouTubeSession", kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    private func keychainDelete() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "AvocadoToast.YouTubeSession",
            kSecAttrAccount as String: key] as CFDictionary)
    }
}
