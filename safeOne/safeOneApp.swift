import SwiftUI

enum UserRole: String, Codable, CaseIterable {
    case elder
    case children

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
