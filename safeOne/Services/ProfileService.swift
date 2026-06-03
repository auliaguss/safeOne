import Foundation

final class ProfileService {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func getProfile(token: String?) async throws -> UserProfile {
        try await apiClient.request("users/me", token: token)
    }

    func updateProfile(_ profile: UserProfile, token: String?) async throws -> UserProfile {
        try await apiClient.request(
            "users/me",
            method: "PUT",
            token: token,
            body: profile
        )
    }

    func getConnectedDevices(token: String?) async throws -> [ConnectedDevice] {
        try await apiClient.request("users/me/devices", token: token)
    }
}

