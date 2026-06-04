import Combine
import AuthenticationServices
import Foundation

private let sukarniID = UUID()
private let jokoID = UUID()
import SwiftUI

@MainActor
class AppState: ObservableObject {
    
    // MARK: - Auth
    @Published var token: String? = nil
    @Published var currentUser: CurrentUser? = nil
    
    // MARK: - Global Incoming Call State
    @Published var incomingCall: IncomingCallData? = nil
    @Published var inActiveCall: Bool = false
    @Published var isAnsweredFromCallKit: Bool = false

    private var pollingTask: Task<Void, Never>? = nil
    
    // MARK: - Elders (local data)
    @Published var session: AuthSession?
    @Published var isLoading = false
    @Published var apiMessage: String?
    @Published var elders: [Elder] = [
        Elder(id: sukarniID, name: "Sukarni"),
        Elder(id: jokoID, name: "Joko")
    ]
    
    @Published var reminders: [Reminder] = [
        Reminder(
            title: "Vitamin D",
            notes: "1 Tablet",
            date: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
            repeatOption: .everyday,
            earlyReminder: .inTime,
            category: .medication,
            isCompleted: true,
            completedCount: 1,
            totalCount: 1,
            elderID: sukarniID,
            imageName: "💊"
        ),
        Reminder(
            title: "Doctor Appointment",
            notes: "",
            date: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
            repeatOption: .none,
            earlyReminder: .none,
            category: .appointment,
            isCompleted: false,
            completedCount: 0,
            totalCount: 1,
            elderID: sukarniID,
            imageName: "🩺"
        ),
        Reminder(
            title: "Antibiotics",
            notes: "",
            date: Calendar.current.date(bySettingHour: 9, minute: 5, second: 0, of: Date())!,
            repeatOption: .everyday,
            earlyReminder: .none,
            category: .medication,
            isCompleted: false,
            completedCount: 1,
            totalCount: 2,
            elderID: sukarniID,
            imageName: "💊"
        ),
        Reminder(
            title: "Paracetamol",
            notes: "",
            date: Calendar.current.date(bySettingHour: 9, minute: 6, second: 0, of: Date())!,
            repeatOption: .everyday,
            earlyReminder: .none,
            category: .medication,
            isCompleted: false,
            completedCount: 1,
            totalCount: 2,
            elderID: jokoID,
            imageName: "💊"
        )
    ]
    
    @Published var selectedElderIndex: Int = 0
    
    // MARK: - Init (load token dari UserDefaults saat app launch)
    init() {
        if let savedToken = UserDefaults.standard.string(forKey: "jwt_token") {
            self.token = savedToken
        }
        if let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(CurrentUser.self, from: userData) {
            self.currentUser = user
        }
    }
    
    // MARK: - Auth Helpers
    
    /// Dipanggil setelah login berhasil (dari Onboarding)
    func saveSession(token: String, user: CurrentUser) {
        self.token = token
        self.currentUser = user
        UserDefaults.standard.set(token, forKey: "jwt_token")
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "current_user")
        }
    }
    
    /// Dipanggil saat logout
    func clearSession() {
        self.token = nil
        self.currentUser = nil
        self.stopPolling() // Matikan polling saat user logout
        UserDefaults.standard.removeObject(forKey: "jwt_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
    }
    
    var isLoggedIn: Bool {
        token != nil && currentUser != nil
    }
    
    var isElder: Bool {
        currentUser?.role == "elder"
    }
    
    var isChild: Bool {
        currentUser?.role == "child"
    }
    
    /// Token yang sudah di-unwrap, fallback ke empty string
    var authToken: String {
        token ?? ""
    }
    
    // MARK: - Elder Helpers
        @Published var profile: UserProfile?

    private let authService = AuthService()
    private let reminderService = ReminderService()
    private let profileService = ProfileService()
    private let supabaseRepository = SupabaseRepository.shared
    private let alertCoordinator = ReminderAlertCoordinator()
    private let localDataStore = LocalDataStore()
    private var alertTask: Task<Void, Never>?

    init() {
        if let savedElders = localDataStore.loadElders(), !savedElders.isEmpty {
            elders = savedElders
        }

        if let savedReminders = localDataStore.loadReminders() {
            reminders = savedReminders
        }

        startAlertMonitoring()
    }

    deinit {
        alertTask?.cancel()
    }

    var selectedElder: Elder? {
        guard elders.indices.contains(selectedElderIndex) else { return nil }
        return elders[selectedElderIndex]
    }

    var activeToken: String? {
        session?.accessToken
    }

    var notificationPreferences: NotificationPreferences {
        profile?.notificationPreferences
            ?? session?.user.notificationPreferences
            ?? NotificationPreferences(sound: .default, hapticsEnabled: true, textToSpeechEnabled: true)
    }

    func restoreSession() async {
        guard session == nil else { return }
        if let restoredSession = authService.restoreSession() {
            session = restoredSession
            profile = restoredSession.user
            startAlertMonitoring()
            await loadProfile()
            await loadElders()
            await loadDashboardReminders(for: Date())
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, role: UserRole, nonce: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let newSession = try await authService.signInWithApple(credential: credential, role: role, nonce: nonce)
            apply(session: newSession)
            await loadProfile()
            await loadElders()
            await loadDashboardReminders(for: Date())
        } catch {
            apiMessage = error.localizedDescription
        }
    }

    func signInLocally(role: UserRole) async {
        apply(session: authService.signInLocally(role: role))
        await loadDashboardReminders(for: Date())
    }

    func logout() async {
        let token = activeToken
        await authService.logout(token: token)
        session = nil
        profile = nil
        alertTask?.cancel()
        alertTask = nil
    }

    func loadDashboardReminders(for date: Date) async {
        let userID: UUID?
        switch session?.user.role {
        case .children:
            userID = selectedElder?.id
        case .elder:
            userID = session?.user.id
        case nil:
            userID = nil
        }

        await loadReminders(date: date, userID: userID)
    }

    func loadReminders(date: Date? = nil, startDate: Date? = nil, endDate: Date? = nil, userID: UUID? = nil) async {
        if supabaseRepository.isAvailable {
            do {
                let backendReminders = try await supabaseRepository.loadReminders(userID: userID)
                merge(reminders: backendReminders)
                return
            } catch {
                apiMessage = "Supabase reminders are not ready yet. Using local reminder data."
            }
        }

        do {
            let backendReminders = try await reminderService.getReminders(
                filter: ReminderFilter(date: date, startDate: startDate, endDate: endDate, userID: userID),
                token: activeToken
            )
            merge(reminders: backendReminders)
        } catch APIError.backendNotConfigured {
            apiMessage = "Using local reminder data until backend is configured."
        } catch {
            apiMessage = error.localizedDescription
        }
    }

    func addReminder(_ reminder: Reminder) {
        reminders.append(reminder)
        persistReminders()
    }

    func createReminder(_ reminder: Reminder) async {
        if supabaseRepository.isAvailable {
            do {
                let created = try await supabaseRepository.upsertReminder(reminder)
                addReminder(created)
                return
            } catch {
                apiMessage = "Supabase reminder save failed. Using local data."
            }
        }

        do {
            let created = try await reminderService.addReminder(reminder, token: activeToken)
            addReminder(created)
        } catch APIError.backendNotConfigured {
            addReminder(reminder)
        } catch {
            apiMessage = error.localizedDescription
            addReminder(reminder)
        }
    }

    func updateReminder(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        persistReminders()
    }

    func saveReminder(_ reminder: Reminder) async {
        if reminders.contains(where: { $0.id == reminder.id }) {
            if supabaseRepository.isAvailable {
                do {
                    let updated = try await supabaseRepository.upsertReminder(reminder)
                    updateReminder(updated)
                    return
                } catch {
                    apiMessage = "Supabase reminder update failed. Using local data."
                }
            }

            do {
                let updated = try await reminderService.editReminder(reminder, token: activeToken)
                updateReminder(updated)
            } catch APIError.backendNotConfigured {
                updateReminder(reminder)
            } catch {
                apiMessage = error.localizedDescription
                updateReminder(reminder)
            }
        } else {
            await createReminder(reminder)
        }
    }

    func deleteReminders(ids: [UUID]) async {
        if supabaseRepository.isAvailable {
            do {
                try await supabaseRepository.deleteReminders(ids: ids)
                reminders.removeAll { ids.contains($0.id) }
                persistReminders()
                return
            } catch {
                apiMessage = "Supabase reminder delete failed. Using local data."
            }
        }

        do {
            try await reminderService.deleteReminders(ids: ids, token: activeToken)
            reminders.removeAll { ids.contains($0.id) }
            persistReminders()
        } catch APIError.backendNotConfigured {
            reminders.removeAll { ids.contains($0.id) }
            persistReminders()
        } catch {
            apiMessage = error.localizedDescription
        }
    }

    func reminders(for elder: Elder?, on date: Date) -> [Reminder] {
        guard let elder else { return [] }

        return reminders.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
                && $0.elderID == elder.id
        }
    }

    func remindersForCurrentUser(on date: Date) -> [Reminder] {
        switch session?.user.role {
        case .elder:
            return reminders.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        case .children:
            return reminders(for: selectedElder, on: date)
        case nil:
            return []
        }
    }

    func loadProfile() async {
        if supabaseRepository.isAvailable {
            do {
                let backendProfile = try await supabaseRepository.loadProfile(roleFallback: session?.user.role ?? .children)
                let devices = try await supabaseRepository.loadConnectedDevices()
                profile = backendProfile
                profile?.connectedDevices = devices
                session?.user = backendProfile
                session?.user.connectedDevices = devices
                await loadElders()
                return
            } catch {
                apiMessage = "Supabase profile sync failed. Using local profile data."
            }
        }

        do {
            let backendProfile = try await profileService.getProfile(token: activeToken)
            profile = backendProfile
            session?.user = backendProfile
        } catch APIError.backendNotConfigured {
            profile = session?.user
        } catch {
            apiMessage = error.localizedDescription
        }
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences) async {
        guard var currentProfile = profile ?? session?.user else { return }
        currentProfile.notificationPreferences = preferences

        if supabaseRepository.isAvailable {
            do {
                let updated = try await supabaseRepository.upsertProfile(currentProfile)
                profile = updated
                session?.user = updated
                return
            } catch {
                apiMessage = "Supabase profile update failed. Using local profile data."
            }
        }

        do {
            let updated = try await profileService.updateProfile(currentProfile, token: activeToken)
            profile = updated
            session?.user = updated
        } catch APIError.backendNotConfigured {
            profile = currentProfile
            session?.user = currentProfile
        } catch {
            apiMessage = error.localizedDescription
            profile = currentProfile
            session?.user = currentProfile
        }
    }

    func loadConnectedDevices() async -> [ConnectedDevice] {
        if supabaseRepository.isAvailable {
            do {
                let devices = try await supabaseRepository.loadConnectedDevices()
                profile?.connectedDevices = devices
                session?.user.connectedDevices = devices
                return devices
            } catch {
                apiMessage = "Supabase device sync failed. Using local device data."
            }
        }

        do {
            let devices = try await profileService.getConnectedDevices(token: activeToken)
            profile?.connectedDevices = devices
            session?.user.connectedDevices = devices
            return devices
        } catch {
            return profile?.connectedDevices ?? session?.user.connectedDevices ?? []
        }
    }

    func loadElders() async {
        if supabaseRepository.isAvailable {
            do {
                let backendElders = try await supabaseRepository.loadElders()
                if !backendElders.isEmpty {
                    elders = backendElders
                    persistElders()
                }
                return
            } catch {
                apiMessage = "Supabase elder sync failed. Using local elder data."
            }
        }
    }

    func addElder(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if supabaseRepository.isAvailable {
            Task {
                do {
                    let newElder = try await supabaseRepository.createElder(name: trimmedName)
                    elders.append(newElder)
                    persistElders()
                } catch {
                    apiMessage = "Supabase elder creation failed. Using local elder data."
                    let newElder = Elder(name: trimmedName)
                    elders.append(newElder)
                    persistElders()
                }
            }
            return
        }

        let newElder = Elder(name: trimmedName)
        elders.append(newElder)
        persistElders()
    }

    func deleteElders(at offsets: IndexSet) {
        let removedIDs = offsets.compactMap { index in
            elders.indices.contains(index) ? elders[index].id : nil
        }

        for index in offsets.sorted(by: >) {
            elders.remove(at: index)
        }

        reminders.removeAll { removedIDs.contains($0.elderID) }

        if selectedElderIndex >= elders.count {
            selectedElderIndex = max(0, elders.count - 1)
        }

        persistElders()
        persistReminders()

        if supabaseRepository.isAvailable {
            Task {
                _ = try? await supabaseRepository.removeElderAssignments(ids: removedIDs)
            }
        }
    }

    private func apply(session newSession: AuthSession) {
        session = newSession
        profile = newSession.user
        startAlertMonitoring()
    }

    private func merge(reminders backendReminders: [Reminder]) {
        for reminder in backendReminders {
            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[index] = reminder
            } else {
                reminders.append(reminder)
            }
        }
        persistReminders()
    }

    private func startAlertMonitoring() {
        guard alertTask == nil else { return }
        alertTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                alertCoordinator.processDueReminders(reminders, preferences: notificationPreferences)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func persistReminders() {
        localDataStore.saveReminders(reminders)
    }

    private func persistElders() {
        localDataStore.saveElders(elders)
    }
    
    // MARK: - Global Polling Helpers
    
    func startPolling() {
        guard isChild else { return } // Pastikan hanya role child/caregiver yang memanggil
        
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await checkIncomingCall()
                try? await Task.sleep(nanoseconds: 3_000_000_000) // Polling setiap 3 detik
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func checkIncomingCall() async {
        // Jangan polling jika sedang ada call
        guard !inActiveCall, incomingCall == nil else { return }
        
        guard let token = self.token else { return }
        guard let url = URL(string: "https://safe-one-backend.vercel.app/api/calls/pending") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            
            let decoded = try JSONDecoder().decode(PendingCallResponse.self, from: data)
            
            await MainActor.run {
                if let call = decoded.call {
                    // Hanya set jika belum ada call
                    if self.incomingCall == nil && !self.inActiveCall {
                        self.incomingCall = IncomingCallData(
                            callId: call.callId,
                            elderName: call.elderName,
                            channelName: call.channelName,
                            agoraToken: call.agoraToken,
                            agoraAppId: call.agoraAppId
                        )
                    }
                }
                // ← HAPUS blok else — jangan pernah nil-kan dari sini
            }
        } catch {
            print("❌ Polling error: \(error)")
        }
    }
}

// MARK: - Models

struct CurrentUser: Codable {
    let id: String
    let name: String
    let role: String      // "elder" | "child"
    let avatar: String?
}

struct IncomingCallData: Identifiable {
    var id: String { callId }
    let callId: String
    let elderName: String
    let channelName: String
    let agoraToken: String
    let agoraAppId: String
}

struct PendingCallResponse: Codable {
    let call: PendingCall?
}

struct PendingCall: Codable {
    let callId: String
    let elderName: String
    let channelName: String
    let agoraToken: String
    let agoraAppId: String
    
    enum CodingKeys: String, CodingKey {
        case callId      = "callId"
        case elderName   = "elderName"
        case channelName = "channelName"
        case agoraToken  = "agoraToken"
        case agoraAppId  = "agoraAppId"
    }
}
