import SwiftUI

struct ElderProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var hapticsEnabled: Bool = true
    @State private var textToSpeechEnabled: Bool = true
    @State private var goToOnboarding = false
    @State private var soundsDefault: String = "Default"
    
    @State private var showEditProfile = false

    
    // OTP State
    @State private var otpCode: String? = nil
    @State private var otpExpiresAt: Date? = nil
    @State private var otpSecondsLeft: Int = 0
    @State private var isGeneratingOtp = false
    @State private var otpTimer: Timer? = nil

    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                // Profile Header — ganti Section yang ada
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
                            Text(appState.currentUser?.name ?? "Elder")
                                .font(.headline)
                            Text("Elder")
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

                // OTP Section
                Section {
                    if let code = otpCode, otpSecondsLeft > 0 {
                        VStack(spacing: 12) {
                            Text("Share this code with your caregiver")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(code)
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .kerning(8)
                                .foregroundColor(.blue)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text("Expires in \(otpSecondsLeft)s")
                                    .font(.caption)
                            }
                            .foregroundColor(otpSecondsLeft < 60 ? .red : .secondary)
                            
                            Button {
                                Task { await generateOtp() }
                            } label: {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        Button {
                            Task { await generateOtp() }
                        } label: {
                            HStack {
                                if isGeneratingOtp {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                }
                                Label("Generate Caregiver Code", systemImage: "qrcode")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(isGeneratingOtp)
                    }
                } header: {
                    Text("Connect Caregiver")
                } footer: {
                    Text("Generate a 6-digit code for your caregiver to enter in their app. Code expires in 30 seconds.")
                }

                // Account
                Section("Account") {
                    NavigationLink("Family") {
                        FamilyListView()
                            .environmentObject(appState)
                    }
                    NavigationLink("Health Information") {
                        HealthInfoView(mode: .edit)
                            .environmentObject(appState)
                    }
                }

                // General
                Section("General") {
                    NavigationLink("Data & Privacy") {
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
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                otpTimer?.invalidate()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            ElderEditProfileView()
                .environmentObject(appState)
        }
    }

    // MARK: - Generate OTP
    private func generateOtp() async {
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/otp/generate")
        else { return }

        isGeneratingOtp = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let code = json["code"] as? String,
                  let expiresInSeconds = json["expiresInSeconds"] as? Int
            else {
                await MainActor.run { isGeneratingOtp = false }
                return
            }

            await MainActor.run {
                otpCode = code
                otpSecondsLeft = expiresInSeconds
                isGeneratingOtp = false
                startOtpCountdown()
            }
        } catch {
            await MainActor.run { isGeneratingOtp = false }
            print("❌ Generate OTP error: \(error)")
        }
    }

    // MARK: - Countdown Timer
    private func startOtpCountdown() {
        otpTimer?.invalidate()
        otpTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if otpSecondsLeft > 0 {
                otpSecondsLeft -= 1
            } else {
                otpTimer?.invalidate()
                otpCode = nil
            }
        }
    }
}


// MARK: - Edit Profile View
struct ElderEditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var avatar: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    let avatarOptions = ["😊", "👴", "👵", "🧓", "👨", "👩", "🧑", "👴🏻", "👵🏻", "🧓🏻"]
    
    var body: some View {
        NavigationStack {
            Form {
                // User ID Section
                Section("Apple User ID") {
                    Text(appState.currentUser?.id ?? "-")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                // Avatar Picker
                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(avatarOptions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 36))
                                .frame(width: 56, height: 56)
                                .background(avatar == emoji ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(avatar == emoji ? Color.blue : Color.clear, lineWidth: 2)
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
                
                // Error
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
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").bold()
                        }
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
        
        let body: [String: String] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "avatar": avatar
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                await MainActor.run {
                    errorMessage = "Failed to save. Try again."
                    isSaving = false
                }
                return
            }
            
            await MainActor.run {
                // Update local AppState
                if let user = appState.currentUser {
                    let updated = CurrentUser(
                        id: user.id,
                        name: json["name"] as? String ?? user.name,
                        role: user.role,
                        avatar: json["avatar"] as? String ?? user.avatar
                    )
                    appState.currentUser = updated
                    // Persist ke UserDefaults
                    if let encoded = try? JSONEncoder().encode(updated) {
                        UserDefaults.standard.set(encoded, forKey: "current_user")
                    }
                }
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Network error. Try again."
                isSaving = false
            }
        }
    }
}

// MARK: - Family List View
struct FamilyListView: View {
    @EnvironmentObject var appState: AppState
    @State private var caregivers: [BackendElder] = []
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if caregivers.isEmpty {
                Text("No caregivers connected yet")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(caregivers) { caregiver in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            if let avatar = caregiver.avatar, !avatar.isEmpty {
                                Text(avatar).font(.title3)
                            } else {
                                Text(String(caregiver.name.prefix(1)))
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(caregiver.name).font(.body).fontWeight(.medium)
                            Text("Caregiver").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Family")
        .task { await fetchCaregivers() }
    }

    private func fetchCaregivers() async {
        guard let token = appState.token,
              let url = URL(string: "\(AppConfig.baseURL)/users/me/caregivers")
        else { return }

        isLoading = true
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let (data, _) = try? await URLSession.shared.data(for: request),
           let decoded = try? JSONDecoder().decode([BackendElder].self, from: data) {
            await MainActor.run {
                caregivers = decoded
                isLoading = false
            }
        } else {
            await MainActor.run { isLoading = false }
        }
    }
}

#Preview {
    ElderProfileView()
        .environmentObject(AppState())
}
