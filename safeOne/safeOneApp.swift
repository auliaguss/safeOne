import SwiftUI

enum UserRole: String, Codable, CaseIterable {
    case elder
    case children = "child"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "elder":
            self = .elder
        case "child", "children":
            self = .children
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported user role: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .elder:
            return "Elder"
        case .children:
            return "Children"
        }
    }
}

@main
struct SafeOneApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.session?.user.role {
                case .elder:
                    ElderContentView()
                case .children:
                    ContentView()
                case nil:
                    Onboarding()
                }
            }
            .environmentObject(appState)
            .task {
                await appState.restoreSession()
            }
        }
    }
}
