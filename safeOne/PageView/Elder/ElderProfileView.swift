import SwiftUI

struct ElderProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var hapticsEnabled: Bool = true
    @State private var textToSpeechEnabled: Bool = true
    @State private var soundsDefault: String = "Default"
    @State private var goToOnboarding = false
    @State private var showEditProfile = false
    @State private var showLogoutConfirmation = false
    @State private var remainingEmergencyCalls = AppConfig.maximumDailyEmergencyCalls

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
                            Text(appState.currentUser?.name ?? appState.text("Lansia", "Elder"))
                                .font(.headline)
                            Text(appState.text("Lansia", "Elder"))
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

                Section {
                    HStack {
                        Label(
                            appState.text("Tersisa hari ini", "Remaining today"),
                            systemImage: "phone.badge.clock"
                        )
                        Spacer()
                        Text(appState.text(
                            "\(remainingEmergencyCalls) dari \(AppConfig.maximumDailyEmergencyCalls)",
                            "\(remainingEmergencyCalls) of \(AppConfig.maximumDailyEmergencyCalls)"
                        ))
                        .fontWeight(.semibold)
                        .foregroundStyle(remainingEmergencyCalls == 0 ? Color.red : Color.blue)
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    Text(appState.text("Kuota Panggilan Darurat", "Emergency Call Allowance"))
                } footer: {
                    Text(appState.text(
                        "Setiap panggilan maksimal 1 menit. Kuota direset setiap hari.",
                        "Each call lasts up to 1 minute. The allowance resets daily."
                    ))
                }

                // OTP Section
                Section {
                    if let code = otpCode, otpSecondsLeft > 0 {
                        VStack(spacing: 12) {
                            Text(appState.text("Bagikan kode ini kepada pendamping Anda", "Share this code with your caregiver"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(code)
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .kerning(8)
                                .foregroundColor(.blue)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text(appState.text("Berlaku selama \(otpSecondsLeft) dtk", "Expires in \(otpSecondsLeft)s"))
                                    .font(.caption)
                            }
                            .foregroundColor(otpSecondsLeft < 60 ? .red : .secondary)
                            
                            Button {
                                Task { await generateOtp() }
                            } label: {
                                Label(appState.text("Buat Ulang", "Regenerate"), systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .tutorialAnchor("elder.connectCode")
                    } else {
                        Button {
                            Task { await generateOtp() }
                        } label: {
                            HStack {
                                if isGeneratingOtp {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                }
                                Label(appState.text("Buat Kode Pendamping", "Generate Caregiver Code"), systemImage: "qrcode")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(isGeneratingOtp)
                        .tutorialAnchor("elder.connectCode")
                    }
                } header: {
                    Text(appState.text("Hubungkan Pendamping", "Connect Caregiver"))
                } footer: {
                    Text(appState.text("Buat kode 6 digit untuk dimasukkan pendamping pada aplikasinya. Kode berlaku 30 detik.", "Generate a 6-digit code for your caregiver to enter in their app. Code expires in 30 seconds."))
                }

                // Account
                Section(appState.text("Akun", "Account")) {
                    NavigationLink(appState.text("Keluarga", "Family")) {
                        FamilyListView()
                            .environmentObject(appState)
                    }
                    NavigationLink(appState.text("Informasi Kesehatan", "Health Information")) {
                        HealthInfoView(mode: .edit)
                            .environmentObject(appState)
                    }
                }

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

                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label(appState.text("Keluar", "Log Out"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppSurfaceBackground())
            .navigationDestination(isPresented: $goToOnboarding) {
                Onboarding(skipExistingUserCheck: true)
            }
            .navigationTitle(appState.text("Profil", "Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshRemainingEmergencyCalls()
            }
            .onChange(of: appState.elderTabSelection) { _, selectedTab in
                if selectedTab == .profile {
                    refreshRemainingEmergencyCalls()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshRemainingEmergencyCalls()
                }
            }
            .onDisappear {
                otpTimer?.invalidate()
            }
            .alert(
                appState.text("Keluar dari akun?", "Log out of your account?"),
                isPresented: $showLogoutConfirmation
            ) {
                Button(appState.text("Batal", "Cancel"), role: .cancel) {}
                Button(appState.text("Keluar", "Log Out"), role: .destructive) {
                    otpTimer?.invalidate()
                    appState.clearSession()
                    goToOnboarding = true
                }
            } message: {
                Text(appState.text("Anda perlu masuk lagi untuk mengakses akun ini.", "You will need to sign in again to access this account."))
            }
        }
        .sheet(isPresented: $showEditProfile) {
            ElderEditProfileView()
                .environmentObject(appState)
        }
    }

    private func refreshRemainingEmergencyCalls() {
        guard let userID = appState.currentUser?.id else {
            remainingEmergencyCalls = 0
            return
        }

        let callsUsed = ElderEmergencyCallQuota.callsUsedToday(for: userID)
        remainingEmergencyCalls = max(AppConfig.maximumDailyEmergencyCalls - callsUsed, 0)
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
                Section(appState.text("ID Pengguna Apple", "Apple User ID")) {
                    Text(appState.currentUser?.id ?? "-")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                // Avatar Picker
                Section(appState.text("Avatar", "Avatar")) {
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
                Section(appState.text("Nama", "Name")) {
                    TextField(appState.text("Masukkan nama Anda", "Enter your name"), text: $name)
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
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(appState.text("Simpan", "Save")).bold()
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
                    errorMessage = appState.text("Gagal menyimpan. Coba lagi.", "Failed to save. Try again.")
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
                errorMessage = appState.text("Kesalahan jaringan. Coba lagi.", "Network error. Try again.")
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
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.text("Pendamping yang terhubung", "Connected caregivers"))
                        .font(.headline)
                    Text(appState.text("Daftar ini menunjukkan anggota keluarga yang saat ini dapat membantu Anda.", "This list shows the family members who can currently support you."))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                if isLoading {
                    ListStatusRow(text: appState.text("Memuat daftar keluarga...", "Loading family list..."), showsProgress: true)
                } else if caregivers.isEmpty {
                    ListStatusRow(text: appState.text("Belum ada pendamping yang terhubung", "No caregivers connected yet"))
                } else {
                    ForEach(caregivers) { caregiver in
                        ConnectedPersonRow(
                            name: caregiver.name,
                            subtitle: appState.text("Pendamping", "Caregiver"),
                            avatar: caregiver.avatar
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppSurfaceBackground())
        .navigationTitle(appState.text("Keluarga", "Family"))
        .navigationBarTitleDisplayMode(.inline)
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
