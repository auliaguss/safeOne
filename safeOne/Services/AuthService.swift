import AuthenticationServices
import Foundation
import Supabase

struct AppleLoginRequest: Codable {
    var identityToken: String
    var authorizationCode: String
    var fullName: String?
    var role: UserRole
    var nonce: String?
}

final class AuthService {
    static let localDevelopmentToken = "local-development-token"

    private let sessionKey = "authSession"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        role: UserRole,
        nonce: String? = nil
    ) async throws -> AuthSession {
        let request = AppleLoginRequest(
            identityToken: String(data: credential.identityToken ?? Data(), encoding: .utf8) ?? "",
            authorizationCode: String(data: credential.authorizationCode ?? Data(), encoding: .utf8) ?? "",
            fullName: credential.fullName?.formatted(),
            role: role,
            nonce: nonce
        )
        if nonce != nil {
            do {
                guard !request.identityToken.isEmpty else {
                    throw AuthServiceError.missingAppleIdentityToken
                }

                let supabaseSession = try await SupabaseManager.shared.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: request.identityToken,
                        nonce: nonce
                    )
                )

                let userID = UUID(uuidString: String(describing: supabaseSession.user.id)) ?? UUID()
                let profile = UserProfile(
                    id: userID,
                    name: Self.displayName(
                        appleName: request.fullName,
                        email: supabaseSession.user.email,
                        role: role
                    ),
                    email: supabaseSession.user.email,
                    role: role,
                    avatar: nil,
                    connectedDevices: [],
                    notificationPreferences: NotificationPreferences(
                        sound: .default,
                        hapticsEnabled: true,
                        textToSpeechEnabled: true
                    )
                )

                let savedProfile = try await SupabaseRepository.shared.upsertProfile(profile)
                let session = AuthSession(
                    accessToken: supabaseSession.accessToken,
                    refreshToken: supabaseSession.refreshToken,
                    user: savedProfile
                )

                save(session)
                return session
            } catch {
                if AuthServiceError.isAppleAudienceMismatch(error) {
                    throw AuthServiceError.appleAudienceMismatch(
                        bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.superAulia.safeOne"
                    )
                }
                throw error
            }
        }

        throw AuthServiceError.missingAppleIdentityToken
    }

    func logout(token: String?) async {
        if SupabaseManager.shared.client.auth.currentSession != nil {
            try? await SupabaseManager.shared.client.auth.signOut()
        }

        SecureStore.deleteData(forKey: sessionKey)
    }

    func restoreSession() -> AuthSession? {
        guard let data = SecureStore.readData(forKey: sessionKey) else {
            return nil
        }
        return try? decoder.decode(AuthSession.self, from: data)
    }

    func clearSavedSession() {
        SecureStore.deleteData(forKey: sessionKey)
    }

    func restoreSupabaseSession(_ session: AuthSession) async throws {
        guard session.accessToken != Self.localDevelopmentToken,
              let refreshToken = session.refreshToken,
              SupabaseManager.shared.client.auth.currentSession == nil
        else {
            return
        }

        _ = try await SupabaseManager.shared.client.auth.setSession(
            accessToken: session.accessToken,
            refreshToken: refreshToken
        )
    }

    private func save(_ session: AuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        SecureStore.saveData(data, forKey: sessionKey)
    }

    private static func displayName(appleName: String?, email: String?, role: UserRole) -> String {
        let trimmedAppleName = appleName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedAppleName, !trimmedAppleName.isEmpty {
            return trimmedAppleName
        }

        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedEmail, !trimmedEmail.isEmpty {
            return trimmedEmail
        }

        return defaultName(for: role)
    }

    private static func defaultName(for role: UserRole) -> String {
        switch role {
        case .elder:
            return "Elder"
        case .children:
            return "Caregiver"
        }
    }
}

enum AuthServiceError: LocalizedError {
    case missingAppleIdentityToken
    case appleAudienceMismatch(bundleIdentifier: String)

    var errorDescription: String? {
        switch self {
        case .missingAppleIdentityToken:
            return "Apple did not return an identity token. Try signing in again."
        case .appleAudienceMismatch(let bundleIdentifier):
            return "Supabase Apple auth is missing Client ID \(bundleIdentifier). Add it in Supabase Auth > Sign In / Providers > Apple."
        }
    }

    static func isAppleAudienceMismatch(_ error: Error) -> Bool {
        error.localizedDescription.localizedCaseInsensitiveContains("unacceptable audience")
    }
}
