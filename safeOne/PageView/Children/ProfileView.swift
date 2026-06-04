//
//  ProfileView.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import SwiftUI

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var hapticsEnabled: Bool = true
    @State private var textToSpeechEnabled: Bool = true
    @State private var goToOnboarding = false
    @State private var soundsDefault: String = "Default"
    @State private var alertsValue: String = "Elders missed 1 reminder"
    
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
                            Text("Bowo Prabu")
                                .font(.headline)
                            Text("Children")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Account
                Section("Account") {
                    NavigationLink("Elder Lists") {
                        ElderListView()
                    }
                    NavigationLink("Connected Devices") {
                        Text("Connected Devices")
                            .navigationTitle("Connected Devices")
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
                    
                    HStack {
                        Text("Alerts")
                        Spacer()
                        Text(alertsValue)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
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

// MARK: - Elder List View (Account > Elder Lists)

struct ElderListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddElder = false
    @State private var newElderName = ""
    
    var body: some View {
        List {
            ForEach(appState.elders) { elder in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemBlue).opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(String(elder.name.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(elder.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Elder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray3))
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                appState.removeElders(atOffsets: indexSet)
            }
        }
        .navigationTitle("Elder Lists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddElder = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .alert("Add Elder", isPresented: $showAddElder) {
            TextField("Elder's name", text: $newElderName)
            Button("Add") {
                if !newElderName.isEmpty {
                    appState.addElder(named: newElderName)
                    newElderName = ""
                }
            }
            Button("Cancel", role: .cancel) { newElderName = "" }
        }
    }
}

#Preview {
    ProfileView()
}
