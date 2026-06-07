import SwiftUI

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
    @State private var showCodeEntry = false
    @State private var pairingCode = ""
    
    var body: some View {
        List {
            Section {
                Text("Enter the code shown on the elder device to connect their account.")
                    .foregroundColor(.secondary)
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
                Button(action: { showCodeEntry = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCodeEntry) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Ask the elder to open Profile and share their pairing code.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("Pairing code", text: $pairingCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button {
                        Task {
                            let joined = await appState.joinPairing(code: pairingCode)
                            if joined {
                                pairingCode = ""
                                showCodeEntry = false
                                await appState.loadElders()
                            }
                        }
                    } label: {
                        Text("Connect Elder")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1.0)
                }
                .padding()
                .navigationTitle("Pairing")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showCodeEntry = false }
                    }
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
