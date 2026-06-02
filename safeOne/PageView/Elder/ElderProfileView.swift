//
//  Profile.swift
//  safeOne
//
//  Created by Aulia Agus on 26/05/26.
//

import SwiftUI

// MARK: - Profile View

struct ElderProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var hapticsEnabled: Bool = true
    @State private var textToSpeechEnabled: Bool = true
    @State private var goToOnboarding = false
    @State private var soundsDefault: String = "Default"
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 50, height: 50)
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sukarni")
                                .font(.headline)
                            Text("Elder")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Account
                Section("Account") {
                    NavigationLink("Family") {
                        Text("Family")
                            .navigationTitle("Family")
                    }
                    NavigationLink("Connected Devices") {
                        Text("Connected Devices")
                            .navigationTitle("Connected Devices")
                    }
                    NavigationLink("Health Information") {
                        Text("Health Information")
                            .navigationTitle("Health Information")
                    }
                }
                
                // Notification
                Section("Notification") {
                    HStack {
                        Text("Sounds")
                        Spacer()
                        Text(soundsDefault)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    Toggle("Text To Speech", isOn: $textToSpeechEnabled)
                    
                }
                
                // General
                Section("General") {
                    NavigationLink("Emergency Services") {
                        Text("Emergency Services")
                            .navigationTitle("Emergency Services")
                    }
                    NavigationLink("Data & Privacy") {
                        Text("Data & Privacy")
                            .navigationTitle("Data & Privacy")
                    }
                    
                }
                Button {
                    goToOnboarding = true
                } label: {
                    Text("Logout")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(16)
                }
                .padding()
            }
            .navigationDestination(isPresented: $goToOnboarding) {
                Onboarding()
            }
            
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


#Preview {
    ElderProfileView()
}
