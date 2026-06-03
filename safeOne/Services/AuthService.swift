import AuthenticationServices
import Foundation
import UIKit

struct AppleLoginRequest: Codable {
    var identityToken: String
    var authorizationCode: String
    var fullName: String?
    var role: UserRole
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

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, role: UserRole) async throws -> AuthSession {
        let request = AppleLoginRequest(
            identityToken: String(data: credential.identityToken ?? Data(), encoding: .utf8) ?? "",
            authorizationCode: String(data: credential.authorizationCode ?? Data(), encoding: .utf8) ?? "",
            fullName: credential.fullName?.formatted(),
            role: role
        )

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
        if let token {
            let _: EmptyResponse? = try? await apiClient.request(
                "auth/logout",
                method: "POST",
                token: token
            )
        }
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    func restoreSession() -> AuthSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else {
            return nil
        }
        return try? decoder.decode(AuthSession.self, from: data)
    }

    private func save(_ session: AuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        UserDefaults.standard.set(data, forKey: sessionKey)
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
