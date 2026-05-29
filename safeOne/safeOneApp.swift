//
//  safeOneApp.swift
//  safeOne
//
//  Created by Aulia Agus on 20/05/26.
//

import SwiftUI

enum UserRole {
    case elder, children
}

@main
struct safeOneApp: App {
    @StateObject private var appState = AppState()
    @State private var userRole: UserRole? = nil

    var body: some Scene {
        WindowGroup {
            if let role = userRole {
                if role == .elder {
                    ElderContentView()
                        .environmentObject(appState)
                } else {
                    ContentView()
                        .environmentObject(appState)
                }
            } else {
                Onboarding(onComplete: { role in userRole = role })
                    .environmentObject(appState)
            }
        }
    }
}

