//
//  AppState.swift
//  ElderCareApp
//

import Foundation
import Combine
import SwiftUI

enum ElderTab: Hashable {
    case dashboard, profile
}

enum ChildTab: Hashable {
    case dashboard, reminders, profile
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case indonesian = "id"
    case english = "en"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .indonesian: return "id_ID"
        case .english: return "en_US"
        }
    }

    var displayName: String {
        switch self {
        case .indonesian: return "Bahasa"
        case .english: return "English"
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app_language") ?? "en") ?? .english
    }

    static func localized(_ indonesian: String, _ english: String) -> String {
        current == .indonesian ? indonesian : english
    }
}

class AppState: ObservableObject {
    // MARK: - Auth
    @Published var token: String? = nil
    @Published var currentUser: CurrentUser? = nil

    // MARK: - Language
    @Published private(set) var language: AppLanguage

    // MARK: - Tab selection (used by TutorialManager to surface a step's real target)
    @Published var elderTabSelection: ElderTab = .dashboard
    @Published var childTabSelection: ChildTab = .dashboard

    // MARK: - Reminder deep-link (set when user taps a push notification)
    @Published var pendingReminderDeepLink: String? = nil

    // MARK: - Active reminder alert (full-screen notification for elder)
    @Published var activeReminderAlert: ReminderNotificationData? = nil

    // MARK: - Global Incoming Call State
    @Published var incomingCall: IncomingCallData? = nil
    @Published var inActiveCall: Bool = false
//    @Published var isAnsweredFromCallKit: Bool = false

    private var pollingTask: Task<Void, Never>? = nil
    
    // MARK: - Elders (local data)
    @Published var elders: [Elder] = [
        Elder(name: "Sukarni"),
        Elder(name: "Joko")
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
            elderID: UUID(),
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
            elderID: UUID(),
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
            elderID: UUID(),
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
            elderID: UUID(),
            imageName: "💊"
        )
    ]
    
    @Published var selectedElderIndex: Int = 0
    
    private var deepLinkObserver: AnyCancellable?
    private var reminderAlertObserver: AnyCancellable?
    private var pushTokenObserver: AnyCancellable?
    // Caches the regular push token in case it arrives before the user logs in
    private var pendingPushToken: String? = nil

    // MARK: - Init (load token dari UserDefaults saat app launch)
    init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app_language") ?? "en") ?? .english
        if let savedToken = UserDefaults.standard.string(forKey: "jwt_token") {
            self.token = savedToken
        }
        if let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(CurrentUser.self, from: userData) {
            self.currentUser = user
        }
        SubscriptionManager.shared.load(for: currentUser?.id, token: token)

        deepLinkObserver = NotificationCenter.default
            .publisher(for: .reminderDeepLink)
            .compactMap { $0.object as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reminderId in
                self?.pendingReminderDeepLink = reminderId
            }

        reminderAlertObserver = NotificationCenter.default
            .publisher(for: .reminderAlert)
            .compactMap { $0.object as? ReminderNotificationData }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.activeReminderAlert = data
            }

        // Save regular push token for ALL users (elder + child).
        // VoIPManager separately handles VoIP tokens in apns_token for calls.
        // This token goes to regular_apns_token — used for reminder & completion notifications.
        pushTokenObserver = NotificationCenter.default
            .publisher(for: .pushTokenRegistered)
            .compactMap { $0.object as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pushToken in
                self?.pendingPushToken = pushToken
                if self?.token != nil { self?.savePushToken(pushToken) }
            }
    }

    // MARK: - Push token

    private func savePushToken(_ pushToken: String) {
        guard let authToken = token,
              let url = URL(string: "\(AppConfig.baseURL)/auth/regular-apns-token") else { return }
        Task {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["regularApnsToken": pushToken])
            _ = try? await URLSession.shared.data(for: req)
            print("✅ Regular push token saved (role: \(currentUser?.role ?? "unknown"))")
        }
    }
    
    // MARK: - Auth Helpers
    
    /// Dipanggil setelah login berhasil (dari Onboarding)
    func saveSession(token: String, user: CurrentUser) {
        self.token = token
        self.currentUser = user
        self.elderTabSelection = .dashboard
        self.childTabSelection = .dashboard
        UserDefaults.standard.set(token, forKey: "jwt_token")
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "current_user")
        }
        SubscriptionManager.shared.load(for: user.id, token: token)
        // Save regular push token for any role that logs in
        if let pushToken = pendingPushToken {
            savePushToken(pushToken)
        }
        
        Task { await VoIPManager.shared.flushPendingVoipToken() }

    }
    
    /// Dipanggil saat logout
    func clearSession() {
        self.token = nil
        self.currentUser = nil
        self.elderTabSelection = .dashboard
        self.childTabSelection = .dashboard
        self.stopPolling() // Matikan polling saat user logout
        UserDefaults.standard.removeObject(forKey: "jwt_token")
        UserDefaults.standard.removeObject(forKey: "current_user")
        SubscriptionManager.shared.load(for: nil, token: nil)
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

    /// Changes the interface language and remembers the choice for the next launch.
    func setLanguage(_ language: AppLanguage) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: "app_language")
    }

    /// Temporary lightweight localization helper while the app's screens are migrated.
    func text(_ indonesian: String, _ english: String) -> String {
        language == .indonesian ? indonesian : english
    }
    
    /// Token yang sudah di-unwrap, fallback ke empty string
    var authToken: String {
        token ?? ""
    }
    
    // MARK: - Elder Helpers
    
    var selectedElder: Elder? {
        guard elders.indices.contains(selectedElderIndex) else { return nil }
        return elders[selectedElderIndex]
    }
    
    func addReminder(_ reminder: Reminder) {
        reminders.append(reminder)
    }
    
    func todayReminders(for elder: Elder?) -> [Reminder] {
        guard elder != nil else { return [] }
        let cal = Calendar.current
        return reminders.filter { cal.isDateInToday($0.date) && !$0.isPast }
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
        guard let url = URL(string: "\(AppConfig.baseURL)/calls/pending") else { return }
        
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

/// Data extracted from a reminder push-notification payload.
/// Carries enough info to show the full-screen alert without a network fetch.
struct ReminderNotificationData: Identifiable {
    let id: String          // reminderId
    let title: String
    let notes: String?
    let imageName: String?
    let time: String        // ISO-8601 date string from the backend
    let category: String?

    var localizedCategory: String {
        switch category?.lowercased() {
        case "medication": return AppLanguage.localized("Obat", "Medication")
        case "appointment": return AppLanguage.localized("Janji temu", "Appointment")
        case "exercise": return AppLanguage.localized("Olahraga", "Exercise")
        case "reminders": return AppLanguage.localized("Pengingat", "Reminders")
        default: return category?.capitalized ?? ""
        }
    }
}

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
