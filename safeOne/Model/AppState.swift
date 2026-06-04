import Combine
import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {

    // MARK: - Auth
    @Published var token: String? = nil
    @Published var currentUser: CurrentUser? = nil
    /// Set to true after an explicit logout so Onboarding skips the auto-sign-in check.
    var didExplicitlyLogOut = false

    // MARK: - Global Incoming Call State
    @Published var incomingCall: IncomingCallData? = nil
    @Published var inActiveCall: Bool = false
    @Published var isAnsweredFromCallKit: Bool = false
    private var pollingTask: Task<Void, Never>? = nil

    // MARK: - UI State
    @Published var isLoading = false
    @Published var apiMessage: String?

    // MARK: - Elders
    @Published var elders: [Elder] = []
    @Published var selectedElderIndex: Int = 0

    // MARK: - Reminders
    @Published var reminders: [Reminder] = []

    // MARK: - Notification Preferences
    @Published var notificationPreferences = NotificationPreferences(
        sound: .default, hapticsEnabled: true, textToSpeechEnabled: true
    )

    // MARK: - Services
    private let supabaseRepository = SupabaseRepository.shared
    private let alertCoordinator = ReminderAlertCoordinator()
    private let localDataStore = LocalDataStore()
    private var alertTask: Task<Void, Never>?

    // MARK: - Init
    init() {
        // Restore auth session from UserDefaults
        if let savedToken = UserDefaults.standard.string(forKey: "jwt_token") {
            self.token = savedToken
        }
        if let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(CurrentUser.self, from: userData) {
            self.currentUser = user
        }

        // Restore persisted data (local cache)
        if let savedElders = localDataStore.loadElders(), !savedElders.isEmpty {
            elders = savedElders
        }
        if let savedReminders = localDataStore.loadReminders() {
            reminders = savedReminders
        }

        // Restore notification preferences
        if let data = UserDefaults.standard.data(forKey: "notification_prefs"),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            notificationPreferences = prefs
        }

        startAlertMonitoring()
    }

    deinit {
        alertTask?.cancel()
    }

    // MARK: - Auth Helpers

    var isLoggedIn: Bool {
        token != nil && currentUser != nil
    }

    var isElder: Bool {
        currentUser?.role == "elder"
    }

    var isChild: Bool {
        currentUser?.role == "child"
    }

    /// JWT token for API requests
    var authToken: String {
        token ?? ""
    }

    /// Current user's UUID derived from device-login user ID
    var currentUserUUID: UUID? {
        currentUser.flatMap { UUID(uuidString: $0.id) }
    }

    /// Computed `UserProfile` for views that display profile data
    var profile: UserProfile? {
        guard let user = currentUser else { return nil }
        let role: UserRole = user.role == "elder" ? .elder : .children
        return UserProfile(
            id: UUID(uuidString: user.id) ?? UUID(),
            name: user.name,
            email: nil,
            role: role,
            avatar: user.avatar,
            connectedDevices: [],
            notificationPreferences: notificationPreferences
        )
    }

    func saveSession(token: String, user: CurrentUser) {
        didExplicitlyLogOut = false
        self.token = token
        self.currentUser = user
        UserDefaults.standard.set(token, forKey: "jwt_token")
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "current_user")
        }
    }

    func clearSession() {
        token = nil
        currentUser = nil
        elders = []
        reminders = []
        stopPolling()
        alertTask?.cancel()
        alertTask = nil
        UserDefaults.standard.removeObject(forKey: "jwt_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
    }

    func logout() async {
        didExplicitlyLogOut = true
        clearSession()
    }

    // MARK: - Profile

    /// No-op: profile is derived from `currentUser` and doesn't need a remote fetch.
    func loadProfile() async {}

    func updateNotificationPreferences(_ preferences: NotificationPreferences) async {
        notificationPreferences = preferences
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "notification_prefs")
        }
    }

    func loadConnectedDevices() async -> [ConnectedDevice] {
        return profile?.connectedDevices ?? []
    }

    // MARK: - Elder Helpers

    var selectedElder: Elder? {
        guard elders.indices.contains(selectedElderIndex) else { return nil }
        return elders[selectedElderIndex]
    }

    // MARK: - Reminder Loading

    func loadDashboardReminders(for date: Date) async {
        let userID = isChild ? selectedElder?.id : currentUserUUID
        await loadReminders(userID: userID)
    }

    func loadReminders(date: Date? = nil, userID: UUID? = nil) async {
        let effectiveUserID = userID ?? currentUserUUID
        guard let effectiveUserID else { return }

        do {
            let fetched = try await supabaseRepository.loadReminders(userID: effectiveUserID)
            merge(reminders: fetched)
        } catch {
            apiMessage = error.localizedDescription
        }
    }

    // MARK: - Reminder CRUD

    func addReminder(_ reminder: Reminder) {
        reminders.append(reminder)
        persistReminders()
    }

    func createReminder(_ reminder: Reminder) async {
        guard let userID = currentUserUUID else {
            addReminder(reminder)
            return
        }

        do {
            let created = try await supabaseRepository.upsertReminder(reminder, createdBy: userID)
            addReminder(created)
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
        guard let userID = currentUserUUID else {
            if reminders.contains(where: { $0.id == reminder.id }) {
                updateReminder(reminder)
            } else {
                addReminder(reminder)
            }
            return
        }

        if reminders.contains(where: { $0.id == reminder.id }) {
            do {
                let updated = try await supabaseRepository.upsertReminder(reminder, createdBy: userID)
                updateReminder(updated)
            } catch {
                apiMessage = error.localizedDescription
                updateReminder(reminder)
            }
        } else {
            await createReminder(reminder)
        }
    }

    func deleteReminders(ids: [UUID]) async {
        do {
            try await supabaseRepository.deleteReminders(ids: ids)
        } catch {
            apiMessage = error.localizedDescription
        }
        reminders.removeAll { ids.contains($0.id) }
        persistReminders()
    }

    func reminders(for elder: Elder?, on date: Date) -> [Reminder] {
        guard let elder else { return [] }
        return reminders.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date) && $0.elderID == elder.id
        }
    }

    func remindersForCurrentUser(on date: Date) -> [Reminder] {
        if isElder {
            return reminders.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        } else if isChild {
            return reminders(for: selectedElder, on: date)
        }
        return []
    }

    // MARK: - Elder Management

    func loadElders() async {
        guard let userID = currentUserUUID, isChild else { return }

        do {
            let fetched = try await supabaseRepository.loadElders(caregiverID: userID)
            if !fetched.isEmpty {
                elders = fetched
                persistElders()
            }
        } catch {
            apiMessage = "Elder sync failed. Using local data."
        }
    }

    func addElder(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        guard let userID = currentUserUUID else {
            let newElder = Elder(name: trimmedName)
            elders.append(newElder)
            persistElders()
            return
        }

        Task {
            do {
                let newElder = try await supabaseRepository.createElder(name: trimmedName, caregiverID: userID)
                elders.append(newElder)
                persistElders()
            } catch {
                apiMessage = "Elder creation failed. Adding locally."
                let newElder = Elder(name: trimmedName)
                elders.append(newElder)
                persistElders()
            }
        }
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

        if let userID = currentUserUUID {
            Task {
                _ = try? await supabaseRepository.removeElderAssignments(ids: removedIDs, caregiverID: userID)
            }
        }
    }

    // MARK: - Private Helpers

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

    // MARK: - Global Polling (Calls)

    func startPolling() {
        guard isChild else { return }
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await checkIncomingCall()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func checkIncomingCall() async {
        guard !inActiveCall, incomingCall == nil else { return }
        guard let token = self.token else { return }
        guard let url = URL(string: "https://safe-one-backend.vercel.app/api/calls/pending") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            let decoded = try JSONDecoder().decode(PendingCallResponse.self, from: data)

            if let call = decoded.call, incomingCall == nil, !inActiveCall {
                incomingCall = IncomingCallData(
                    callId: call.callId,
                    elderName: call.elderName,
                    channelName: call.channelName,
                    agoraToken: call.agoraToken,
                    agoraAppId: call.agoraAppId
                )
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
