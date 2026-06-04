import AuthenticationServices
import Foundation
import Supabase
import UIKit

struct AppleLoginRequest: Codable {
    var identityToken: String
    var authorizationCode: String
    var fullName: String?
    var role: UserRole
    var nonce: String?
}

final class AuthService {
    private let apiClient: APIClient
    private let sessionKey = "authSession"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
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

        if let nonce {
            do {
                let supabaseSession = try await SupabaseManager.shared.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: request.identityToken
                    )
                )

                let userID = UUID(uuidString: String(describing: supabaseSession.user.id)) ?? UUID()
                let profile = UserProfile(
                    id: userID,
                    name: request.fullName ?? supabaseSession.user.email ?? "SafeOne User",
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

                let session = AuthSession(
                    accessToken: supabaseSession.accessToken,
                    refreshToken: supabaseSession.refreshToken,
                    user: profile
                )

                save(session)
                _ = try? await SupabaseRepository.shared.upsertProfile(profile)
                return session
            } catch {
                // Fall back to the current development flow if Supabase auth is not ready yet.
            }
        }

        do {
            let session: AuthSession = try await apiClient.request(
                "auth/apple",
                method: "POST",
                body: request
            )
            save(session)
            return session
        } catch APIError.backendNotConfigured {
            let fallback = localSession(role: role, name: request.fullName)
            save(fallback)
            return fallback
        }
    }

    func signInLocally(role: UserRole) -> AuthSession {
        let session = localSession(role: role, name: nil)
        save(session)
        return session
    }

    func logout(token: String?) async {
        if SupabaseManager.shared.client.auth.currentSession != nil {
            try? await SupabaseManager.shared.client.auth.signOut()
        }

        if let token {
            let _: EmptyResponse? = try? await apiClient.request(
                "auth/logout",
                method: "POST",
                token: token
            )
        }
        SecureStore.deleteData(forKey: sessionKey)
    }

    func restoreSession() -> AuthSession? {
        guard let data = SecureStore.readData(forKey: sessionKey) else {
            return nil
        }
        return try? decoder.decode(AuthSession.self, from: data)
    }

    private func save(_ session: AuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        SecureStore.saveData(data, forKey: sessionKey)
    }

    private func localSession(role: UserRole, name: String?) -> AuthSession {
        AuthSession(
            accessToken: "local-development-token",
            refreshToken: nil,
            user: UserProfile(
                id: UUID(),
                name: name ?? (role == .elder ? "Sukarni" : "Bowo Prabu"),
                email: nil,
                role: role,
                avatar: nil,
                connectedDevices: [
                    ConnectedDevice(
                        id: UUID(),
                        name: UIDevice.current.name,
                        role: role,
                        isCurrentDevice: true,
                        lastSeenAt: Date()
                    )
                ],
                notificationPreferences: NotificationPreferences(
                    sound: .default,
                    hapticsEnabled: true,
                    textToSpeechEnabled: true
                )
            )
        )
    }
}
