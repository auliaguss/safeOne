import SwiftUI

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var goToOnboarding = false
    @State private var showEditProfile = false
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
                            if let avatar = appState.currentUser?.avatar, !avatar.isEmpty {
                                Text(avatar)
                                    .font(.system(size: 28))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.currentUser?.name ?? "Caregiver")
                                .font(.headline)
                            Text("Children")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { showEditProfile = true }
                }

                // Account
                Section("Account") {
                    NavigationLink("Elder Lists") {
                        Text("Elder Lists")
                            .navigationTitle("Elder Lists")
                    }
                }

                // Notification
                Section("Notification") {
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
                        Text("Emergency Services").navigationTitle("Emergency Services")
                    }
                    NavigationLink("Data & Privacy") {
                        Text("Data & Privacy").navigationTitle("Data & Privacy")
                    }
                }

                
            }
            .navigationDestination(isPresented: $goToOnboarding) {
                Onboarding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(appState)
            }
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var avatar: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    let avatarOptions = ["😊", "👦", "👧", "👨", "👩", "🧑", "👴", "👵", "🧓", "🙂"]

    var body: some View {
        NavigationStack {
            Form {
                // User ID
                Section("User ID") {
                    Text(appState.currentUser?.id ?? "-")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                // Avatar
                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(avatarOptions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 36))
                                .frame(width: 56, height: 56)
                                .background(avatar == emoji ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(avatar == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture { avatar = emoji }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Name
                Section("Name") {
                    TextField("Enter your name", text: $name)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save").bold() }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = appState.currentUser?.name ?? ""
                avatar = appState.currentUser?.avatar ?? ""
            }
        }
    }

    private func saveProfile() async {
        guard let token = appState.token,
              let url = URL(string: "https://safe-one-backend.vercel.app/api/users/me")
        else { return }

        isSaving = true
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "name": name.trimmingCharacters(in: .whitespaces),
            "avatar": avatar
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                await MainActor.run { errorMessage = "Failed to save. Try again."; isSaving = false }
                return
            }

            await MainActor.run {
                if let user = appState.currentUser {
                    let updated = CurrentUser(
                        id: user.id,
                        name: json["name"] as? String ?? user.name,
                        role: user.role,
                        avatar: json["avatar"] as? String ?? user.avatar
                    )
                    appState.currentUser = updated
                    if let encoded = try? JSONEncoder().encode(updated) {
                        UserDefaults.standard.set(encoded, forKey: "current_user")
                    }
                }
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run { errorMessage = "Network error. Try again."; isSaving = false }
        }
    }
}
