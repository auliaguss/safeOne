//
//  ContentView.swift
//  safeOne
//
//  Created by Aulia Agus on 20/05/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView{
            Tab("Dashboard", systemImage: "checklist") {
                Home()
            }
            
            Tab("Reminders", systemImage: "bell.fill") {
                Reminders()
            }
            
            Tab("Profile", systemImage: "person.fill") {
                Profile()
            }
            
        }
    }
}

#Preview {
    ContentView()
}
