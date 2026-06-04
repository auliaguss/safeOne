import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var preferences = NotificationPreferences(sound: .default, hapticsEnabled: true, textToSpeechEnabled: true)

    var body: some View {
        NavigationStack {
            List {
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
                            Text(appState.profile?.name ?? appState.session?.user.name ?? "SafeOne User")
                                .font(.headline)
                            Text(appState.profile?.role.displayName ?? "Children")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Account") {
                    NavigationLink("Paired Elders") {
                        ElderListView()
                    }
                    NavigationLink("Connected Devices") {
                        ConnectedDevicesView()
                    }
                    NavigationLink("Emergency Services") {
                        EmergencyContactsView()
                    }
                }

                Section("Notification") {
                    Menu {
                        ForEach(AlertSound.allCases, id: \.self) { sound in
                            Button(sound.rawValue) {
                                preferences.sound = sound
                                savePreferences()
                            }
                        }
                    } label: {
                        HStack {
                            Text("Sounds")
                            Spacer()
                            Text(preferences.sound.rawValue)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("Haptics", isOn: $preferences.hapticsEnabled)
                        .onChange(of: preferences.hapticsEnabled) { savePreferences() }
                    Toggle("Text To Speech", isOn: $preferences.textToSpeechEnabled)
                        .onChange(of: preferences.textToSpeechEnabled) { savePreferences() }
                }

                Section("General") {
                    NavigationLink("Data & Privacy") {
                        Text("Data & Privacy")
                            .navigationTitle("Data & Privacy")
                    }
                }

                Button {
                    Task {
                        await appState.logout()
                    }
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await appState.loadProfile()
                preferences = appState.notificationPreferences
            }
        }
    }

    private func savePreferences() {
        Task {
            await appState.updateNotificationPreferences(preferences)
        }
    }
}

struct ElderListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCodeShare = false
    @State private var pairingCode: String?
    
    var body: some View {
        List {
            Section {
                if let pairingCode {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pairing Code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(pairingCode)
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = pairingCode
                        }
                    }
                } else {
                    Text("Generate a pairing code to connect an elder account.")
                        .foregroundColor(.secondary)
                }
            }

            if appState.elders.isEmpty {
                Text("No paired elders yet.")
                    .foregroundColor(.secondary)
            } else {
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
                            Text("Shown on monitoring dashboard")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    appState.deleteElders(at: indexSet)
                }
            }
        }
        .navigationTitle("Paired Elders")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCodeShare = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCodeShare) {
            NavigationStack {
                VStack(spacing: 20) {
                    if let pairingCode {
                        Text("Share this code with the elder device.")
                            .foregroundColor(.secondary)
                        Text(pairingCode)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        Text("Generate a code to begin pairing.")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        Task {
                            pairingCode = await appState.generatePairingCode()
                        }
                    } label: {
                        Text(pairingCode == nil ? "Generate Pairing Code" : "Regenerate Code")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
                .navigationTitle("Pairing")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showCodeShare = false }
                    }
                }
                .onAppear {
                    pairingCode = appState.pairingCode
                }
            }
        }
    }
}

struct ConnectedDevicesView: View {
    @EnvironmentObject var appState: AppState
    @State private var devices: [ConnectedDevice] = []

    var body: some View {
        List {
            ForEach(devices) { device in
                HStack(spacing: 14) {
                    Image(systemName: device.role == .elder ? "heart.text.square.fill" : "person.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.body)
                        Text(device.role.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if device.isCurrentDevice {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Connected Devices")
        .task {
            devices = await appState.loadConnectedDevices()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
