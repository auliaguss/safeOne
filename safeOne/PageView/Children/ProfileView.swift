//
//  ProfileView.swift
//  safeOne
//

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
                // Profile Header — tap untuk edit
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
                            Text(appState.currentUser?.name ?? appState.text("Pendamping", "Caregiver"))
                                .font(.headline)
                            Text(appState.text("Keluarga", "Family"))
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
                Section(appState.text("Akun", "Account")) {
                    NavigationLink(appState.text("Daftar Lansia", "Elder Lists")) {
                        ElderListView()
                            .environmentObject(appState)
                    }
                    .tutorialAnchor("child.connectElder")
                }

                // Notification
                // Section("Notification") {
                //     HStack {
                //         Text("Alerts")
                //         Spacer()
                //         Text(alertsValue)
                //             .foregroundColor(.secondary)
                //             .font(.subheadline)
                //         Image(systemName: "chevron.up.chevron.down")
                //             .font(.caption2)
                //             .foregroundColor(.secondary)
                //     }
                // }

                Section(appState.text("Bahasa", "Language")) {
                    Picker(selection: Binding(
                        get: { appState.language },
                        set: { appState.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    } label: {
                        Label(appState.text("Bahasa aplikasi", "App language"), systemImage: "globe")
                    }
                    .pickerStyle(.menu)
                    .accessibilityHint(appState.text("Pilih Bahasa Indonesia atau English", "Choose Bahasa Indonesia or English"))
                }

                // General
                Section(appState.text("Umum", "General")) {
                    NavigationLink(appState.text("Data & Privasi", "Data & Privacy")) {
                        DataPrivacyView()
                    }
                }


            }
            .scrollContentBackground(.hidden)
            .background(
                ZStack {
                    Color.white
                    RadialGradient(
                        colors: [Color(red: 0, green: 218/255, blue: 195/255).opacity(0.15), Color.clear],
                        center: UnitPoint(x: 0.2, y: 0.1),
                        startRadius: 0,
                        endRadius: 400
                    )
                    RadialGradient(
                        colors: [Color(red: 0, green: 145/255, blue: 1.0).opacity(0.20), Color.clear],
                        center: UnitPoint(x: 0.8, y: 0.8),
                        startRadius: 0,
                        endRadius: 400
                    )
                }
                .ignoresSafeArea()
            )
            .navigationDestination(isPresented: $goToOnboarding) {
                Onboarding()
            }
            .navigationTitle(appState.text("Profil", "Profile"))
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
                Section(appState.text("ID Pengguna", "User ID")) {
                    Text(appState.currentUser?.id ?? "-")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                Section(appState.text("Avatar", "Avatar")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(avatarOptions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 36))
                                .frame(width: 56, height: 56)
                                .background(avatar == emoji ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(avatar == emoji ? Color.blue : Color.clear, lineWidth: 2))
                                .onTapGesture { avatar = emoji }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(appState.text("Nama", "Name")) {
                    TextField(appState.text("Masukkan nama Anda", "Enter your name"), text: $name)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(appState.text("Ubah Profil", "Edit Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(appState.text("Batal", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving { ProgressView() } else { Text(appState.text("Simpan", "Save")).bold() }
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
              let url = URL(string: "\(AppConfig.baseURL)/users/me")
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
                await MainActor.run { errorMessage = self.appState.text("Gagal menyimpan. Coba lagi.", "Failed to save. Try again."); isSaving = false }
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
            await MainActor.run { errorMessage = self.appState.text("Kesalahan jaringan. Coba lagi.", "Network error. Try again."); isSaving = false }
        }
    }
}

// MARK: - Elder List View
struct ElderListView: View {
    @EnvironmentObject var appState: AppState
    @State private var elders: [BackendElder] = []
    @State private var isLoading = false
    @State private var showAddElder = false
    @State private var otpCode = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if elders.isEmpty {
                Text(appState.text("Belum ada lansia yang terhubung", "No elders connected yet"))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(elders) { elder in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            if let avatar = elder.avatar, !avatar.isEmpty {
                                Text(avatar).font(.title3)
                            } else {
                                Text(String(elder.name.prefix(1)))
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(elder.name).font(.body).fontWeight(.medium)
                            Text(appState.text("Lansia", "Elder")).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await removeElder(elders[index].id)
                        }
                    }
                }
            }
        }
        .navigationTitle(appState.text("Daftar Lansia", "Elder Lists"))
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
        .alert(appState.text("Tambah Lansia dengan OTP", "Add Elder via OTP"), isPresented: $showAddElder) {
            TextField(appState.text("Masukkan Kode OTP", "Enter OTP Code"), text: $otpCode)
                .keyboardType(.numberPad)
            Button(appState.text("Tambah", "Add")) { Task { await verifyOtp() } }
            Button(appState.text("Batal", "Cancel"), role: .cancel) {
                otpCode = ""
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? appState.text("Masukkan kode OTP dari perangkat lansia.", "Enter the OTP code from the elder's device."))
        }
        .task { await fetchElders() }
    }

    private func fetchElders() async {
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/users/me/elders")
        else { return }

        isLoading = true
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let (data, _) = try? await URLSession.shared.data(for: request),
           let decoded = try? JSONDecoder().decode([BackendElder].self, from: data) {
            await MainActor.run {
                elders = decoded
                isLoading = false
            }
        } else {
            await MainActor.run { isLoading = false }
        }
    }

    private func removeElder(_ elderId: String) async {
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/users/me/elders/\(elderId)")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200 {
            await MainActor.run {
                elders.removeAll { $0.id == elderId }
            }
        }
    }

    private func verifyOtp() async {
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/otp/verify")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["code": otpCode])

        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse {
            if http.statusCode == 200 {
                await MainActor.run {
                    otpCode = ""
                    errorMessage = nil
                }
                await fetchElders()
            } else {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let msg = json?["error"] as? String ?? appState.text("Kode OTP tidak valid", "Invalid OTP code")
                await MainActor.run {
                    errorMessage = msg
                    otpCode = ""
                }
            }
        }
    }
}

// MARK: - Model
struct BackendElder: Codable, Identifiable {
    let id: String
    let name: String
    let avatar: String?
    let connectedSince: String?

    enum CodingKeys: String, CodingKey {
        case id, name, avatar
        case connectedSince = "connected_since"
    }
}
