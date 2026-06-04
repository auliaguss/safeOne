import SwiftUI

struct ElderProfileView: View {
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
                            Text(appState.profile?.role.displayName ?? "Elder")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Account") {
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


#Preview {
    ElderProfileView()
        .environmentObject(AppState())
}
