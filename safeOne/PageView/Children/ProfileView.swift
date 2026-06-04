import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var preferences = NotificationPreferences(sound: .default, hapticsEnabled: true, textToSpeechEnabled: true)
    private let alertsValue = "Elders missed 1 reminder"

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
                            Text(appState.profile?.name ?? "Bowo Prabu")
                                .font(.headline)
                            Text(appState.profile?.role.displayName ?? "Children")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Account") {
                    NavigationLink("Elder Lists") {
                        ElderListView()
                    }
                    NavigationLink("Connected Devices") {
                        ConnectedDevicesView()
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
        .navigationTitle("Elder Lists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddElder = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add Elder", isPresented: $showAddElder) {
            TextField("Elder's name", text: $newElderName)
            Button("Add") {
                appState.addElder(name: newElderName)
                newElderName = ""
            }
            Button("Cancel", role: .cancel) { newElderName = "" }
        } message: {
            Text("This elder will appear on the dashboard filter.")
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
