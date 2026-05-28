//
//  safeOneApp.swift
//  safeOne
//
//  Created by Aulia Agus on 20/05/26.
//

import SwiftUI

@main
struct safeOneApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
