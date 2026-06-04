import Combine
import AuthenticationServices
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var session: AuthSession?
    @Published var isLoading = false
    @Published var apiMessage: String?
    @Published var elders: [Elder] = []
    @Published var reminders: [Reminder] = []
    @Published var selectedElderIndex: Int = 0
    @Published var profile: UserProfile?
    @Published var pairingCode: String?
    @Published var pairings: [PairingRecord] = []
    @Published var emergencyContacts: [EmergencyContact] = []

    private let authService = AuthService()
    private let reminderService = ReminderService()
    private let profileService = ProfileService()
    private let supabaseRepository = SupabaseRepository.shared
    private let alertCoordinator = ReminderAlertCoordinator()
    private let localDataStore = LocalDataStore()
    private let notificationService = NotificationService.shared
    private let faceTimeService = FaceTimeService.shared
    private var alertTask: Task<Void, Never>?

    init() {
        if let savedElders = localDataStore.loadElders() {
            elders = savedElders
        }

        if let savedReminders = localDataStore.loadReminders() {
            reminders = savedReminders
        }

        if let savedPairings = localDataStore.loadPairings() {
            pairings = savedPairings
        }

        if let savedContacts = localDataStore.loadEmergencyContacts() {
            emergencyContacts = savedContacts
        }

        startAlertMonitoring()
        Task {
            await notificationService.requestAuthorization()
        }
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

    var currentFaceTimeContacts: [FaceTimeContact] {
        let contacts = emergencyContacts
            .filter { $0.category == .caregiver || $0.isPrimary }
            .map {
                FaceTimeContact(
                    id: $0.id,
                    name: $0.name,
                    address: $0.phoneNumber,
                    isPrimary: $0.isPrimary
                )
            }

        if contacts.isEmpty {
            return emergencyContacts.map {
                FaceTimeContact(id: $0.id, name: $0.name, address: $0.phoneNumber, isPrimary: $0.isPrimary)
            }
        }

        return contacts
    }

    func bootstrap() async {
        await notificationService.requestAuthorization()
        await restoreSession()
    }

    func restoreSession() async {
        guard session == nil else {
            await syncAppData(for: session?.user.role)
            return
        }

        if let restoredSession = authService.restoreSession() {
            session = restoredSession
            profile = restoredSession.user
            startAlertMonitoring()
            await syncAppData(for: restoredSession.user.role)
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, role: UserRole, nonce: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let newSession = try await authService.signInWithApple(credential: credential, role: role, nonce: nonce)
            apply(session: newSession)
            await syncAppData(for: role)
        } catch {
            apiMessage = error.localizedDescription
        }
    }

    func signInLocally(role: UserRole) async {
        apply(session: authService.signInLocally(role: role))
        await syncAppData(for: role)
    }

    func logout() async {
        let token = activeToken
        await authService.logout(token: token)
        session = nil
        profile = nil
        elders = []
        reminders = []
        pairings = []
        pairingCode = nil
        emergencyContacts = []
        selectedElderIndex = 0
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
                await rescheduleNotifications(for: backendReminders)
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
            await rescheduleNotifications(for: backendReminders)
        } catch APIError.backendNotConfigured {
            apiMessage = "Using local reminder data until backend is configured."
        } catch {
            apiMessage = error.localizedDescription
        }
    }

    func remindersForCurrentUser(on date: Date) -> [Reminder] {
        switch session?.user.role {
        case .elder:
            return reminders.filter {
                $0.elderID == session?.user.id
                    && Calendar.current.isDate($0.date, inSameDayAs: date)
            }
        case .children:
            return reminders(for: selectedElder, on: date)
        case nil:
            return []
        }
    }

    func reminderProgress(on date: Date) -> ReminderProgressSummary {
        let current = remindersForCurrentUser(on: date)
        let total = current.reduce(0) { $0 + max($1.totalCount, 1) }
        let completed = current.reduce(0) { $0 + min($1.completedCount, max($1.totalCount, 1)) }
        return ReminderProgressSummary(completed: completed, total: total)
    }

    func createReminder(_ reminder: Reminder) async {
        if supabaseRepository.isAvailable {
            do {
                let created = try await supabaseRepository.upsertReminder(reminder)
                addReminder(created)
                await notificationService.schedule(reminder: created)
                return
            } catch {
                apiMessage = "Supabase reminder save failed. Using local data."
            }
        }

        do {
            let created = try await reminderService.addReminder(reminder, token: activeToken)
            addReminder(created)
            await notificationService.schedule(reminder: created)
        } catch APIError.backendNotConfigured {
            addReminder(reminder)
            await notificationService.schedule(reminder: reminder)
        } catch {
            apiMessage = error.localizedDescription
            addReminder(reminder)
            await notificationService.schedule(reminder: reminder)
        }
    }

    func saveReminder(_ reminder: Reminder) async {
        if reminders.contains(where: { $0.id == reminder.id }) {
            if supabaseRepository.isAvailable {
                do {
                    let updated = try await supabaseRepository.upsertReminder(reminder)
                    updateReminder(updated)
                    await notificationService.schedule(reminder: updated)
                    return
                } catch {
                    apiMessage = "Supabase reminder update failed. Using local data."
                }
            }

            do {
                let updated = try await reminderService.editReminder(reminder, token: activeToken)
                updateReminder(updated)
                await notificationService.schedule(reminder: updated)
            } catch APIError.backendNotConfigured {
                updateReminder(reminder)
                await notificationService.schedule(reminder: reminder)
            } catch {
                apiMessage = error.localizedDescription
                updateReminder(reminder)
                await notificationService.schedule(reminder: reminder)
            }
        } else {
            await createReminder(reminder)
        }
    }

    func deleteReminders(ids: [UUID]) async {
        if supabaseRepository.isAvailable {
            do {
                try await supabaseRepository.deleteReminders(ids: ids)
                removeReminderIDs(ids)
                return
            } catch {
                apiMessage = "Supabase reminder delete failed. Using local data."
            }
        }

        do {
            try await reminderService.deleteReminders(ids: ids, token: activeToken)
            removeReminderIDs(ids)
        } catch APIError.backendNotConfigured {
            removeReminderIDs(ids)
        } catch {
            apiMessage = error.localizedDescription
        }
    }

    func completeReminder(_ reminder: Reminder) async {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var updated = reminders[index]
        let totalCount = max(updated.totalCount, 1)
        updated.completedCount = min(totalCount, max(updated.completedCount + 1, 1))
        updated.isCompleted = updated.completedCount >= totalCount
        reminders[index] = updated
        persistReminders()
        alertCoordinator.markCompleted(updated.id)
        await saveReminder(updated)
        await notificationService.cancel(reminderID: updated.id)
    }

    func snoozeReminder(_ reminder: Reminder, minutes: Int = 5) async {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var updated = reminders[index]
        updated.date = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date()
        updated.isCompleted = false
        reminders[index] = updated
        persistReminders()
        alertCoordinator.resetAlertState(for: updated.id)
        await notificationService.schedule(reminder: updated)
        await saveReminder(updated)
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
                await loadPairings()
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
                elders = backendElders
                persistElders()
                return
            } catch {
                apiMessage = "Supabase elder sync failed. Using local elder data."
            }
        }

        guard session?.user.role == .children else {
            elders = []
            persistElders()
            return
        }

        syncEldersFromPairings()
    }

    func loadPairings() async {
        if supabaseRepository.isAvailable {
            do {
                pairings = try await supabaseRepository.loadPairings()
                persistPairings()
                syncPairingUIState()
                return
            } catch {
                apiMessage = "Supabase pairing sync failed. Using local pairing data."
            }
        }

        if let saved = localDataStore.loadPairings() {
            pairings = saved
        }

        syncPairingUIState()
    }

    func generatePairingCode() async -> String? {
        if supabaseRepository.isAvailable {
            do {
                let record = try await supabaseRepository.generatePairingCode()
                upsertPairing(record)
                syncPairingUIState()
                return record.pairingCode
            } catch {
                apiMessage = error.localizedDescription
            }
        }

        guard let caregiverID = session?.user.id else { return nil }
        let record = PairingRecord(
            pairingCode: Self.makePairingCode(),
            caregiverID: caregiverID,
            caregiverName: profile?.name ?? session?.user.name ?? "SafeOne User",
            elderID: nil,
            elderName: nil
        )
        upsertPairing(record)
        syncPairingUIState()
        return record.pairingCode
    }

    func joinPairing(code: String) async -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }

        if supabaseRepository.isAvailable {
            do {
                let record = try await supabaseRepository.joinPairing(code: normalized)
                upsertPairing(record)
                syncPairingUIState()
                return true
            } catch {
                apiMessage = error.localizedDescription
            }
        }

        guard let existingIndex = pairings.firstIndex(where: { $0.pairingCode == normalized }) else {
            apiMessage = "Pairing code was not found."
            return false
        }

        var record = pairings[existingIndex]
        record.elderID = session?.user.id
        record.elderName = profile?.name ?? session?.user.name
        record.updatedAt = Date()
        pairings[existingIndex] = record
        persistPairings()
        syncPairingUIState()
        return true
    }

    func loadEmergencyContacts() {
        if let contacts = localDataStore.loadEmergencyContacts() {
            emergencyContacts = contacts
        }
    }

    func saveEmergencyContacts(_ contacts: [EmergencyContact]) {
        emergencyContacts = contacts
        persistEmergencyContacts()
    }

    func addEmergencyContact(_ contact: EmergencyContact) {
        emergencyContacts.append(contact)
        persistEmergencyContacts()
    }

    func updateEmergencyContact(_ contact: EmergencyContact) {
        guard let index = emergencyContacts.firstIndex(where: { $0.id == contact.id }) else { return }
        emergencyContacts[index] = contact
        persistEmergencyContacts()
    }

    func deleteEmergencyContacts(ids: [UUID]) {
        emergencyContacts.removeAll { ids.contains($0.id) }
        persistEmergencyContacts()
    }

    func openFaceTime(using contact: FaceTimeContact? = nil) {
        let target = contact ?? faceTimeContact()
        guard let target else {
            apiMessage = "Add a paired caregiver contact before starting FaceTime."
            return
        }
        faceTimeService.open(address: target.address)
    }

    func faceTimeContact(for category: EmergencyContactCategory = .caregiver) -> FaceTimeContact? {
        if let primary = currentFaceTimeContacts.first(where: { $0.isPrimary }) {
            return primary
        }

        if let categorized = currentFaceTimeContacts.first(where: { $0.name.lowercased().contains(category.rawValue.lowercased()) }) {
            return categorized
        }

        return currentFaceTimeContacts.first
    }

    func reminders(for elder: Elder?, on date: Date) -> [Reminder] {
        guard let elder else { return [] }

        return reminders.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
                && $0.elderID == elder.id
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
    }

    private func syncAppData(for role: UserRole?) async {
        loadEmergencyContacts()
        await loadProfile()
        await loadPairings()
        await loadElders()
        await loadReminders(userID: session?.user.role == .children ? selectedElder?.id : session?.user.id)

        if role == .children {
            pairingCode = pairings.first(where: { $0.caregiverID == session?.user.id })?.pairingCode
        } else {
            pairingCode = nil
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

    private func upsertPairing(_ record: PairingRecord) {
        if let index = pairings.firstIndex(where: { $0.pairingCode == record.pairingCode }) {
            pairings[index] = record
        } else {
            pairings.append(record)
        }
        persistPairings()
    }

    private func syncPairingUIState() {
        if session?.user.role == .children {
            pairingCode = pairings.first(where: { $0.caregiverID == session?.user.id })?.pairingCode
            elders = pairings
                .filter { $0.caregiverID == session?.user.id }
                .filter { $0.elderID != nil }
                .map {
                    Elder(
                        id: $0.elderID ?? $0.id,
                        name: $0.elderName ?? "Paired Elder",
                        avatar: nil
                    )
                }
        } else {
            pairingCode = nil
        }
        if session?.user.role == .children {
            persistElders()
        }
    }

    private func syncEldersFromPairings() {
        guard session?.user.role == .children else {
            elders = []
            persistElders()
            return
        }

        elders = pairings
            .filter { $0.caregiverID == session?.user.id }
            .filter { $0.elderID != nil }
            .map {
                Elder(
                    id: $0.elderID ?? $0.id,
                    name: $0.elderName ?? "Paired Elder",
                    avatar: nil
                )
            }
        persistElders()
    }

    private func startAlertMonitoring() {
        guard alertTask == nil else { return }
        alertTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await MainActor.run { [self] in
                    alertCoordinator.processDueReminders(reminders, preferences: notificationPreferences)
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func addReminder(_ reminder: Reminder) {
        reminders.append(reminder)
        persistReminders()
    }

    private func updateReminder(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        persistReminders()
    }

    private func removeReminderIDs(_ ids: [UUID]) {
        reminders.removeAll { ids.contains($0.id) }
        persistReminders()
        Task {
            for id in ids {
                await notificationService.cancel(reminderID: id)
                await MainActor.run {
                    alertCoordinator.resetAlertState(for: id)
                }
            }
        }
    }

    private func persistReminders() {
        localDataStore.saveReminders(reminders)
    }

    private func persistElders() {
        localDataStore.saveElders(elders)
    }

    private func persistPairings() {
        localDataStore.savePairings(pairings)
    }

    private func persistEmergencyContacts() {
        localDataStore.saveEmergencyContacts(emergencyContacts)
    }

    private func rescheduleNotifications(for reminders: [Reminder]) async {
        for reminder in reminders {
            await notificationService.schedule(reminder: reminder)
        }
    }

    private static func makePairingCode(length: Int = 6) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var code = ""
        while code.count < length {
            code.append(alphabet.randomElement() ?? "A")
        }
        return code
    }
}
