//
//  AppState.swift
//  ElderCareApp
//

import Foundation
import Combine
import SwiftUI

class AppState: ObservableObject {
    
    // MARK: - Auth
    @Published var token: String? = nil
    @Published var currentUser: CurrentUser? = nil

    // MARK: - Reminder deep-link (set when user taps a push notification)
    @Published var pendingReminderDeepLink: String? = nil

    // MARK: - Active reminder alert (full-screen notification for elder)
    @Published var activeReminderAlert: ReminderNotificationData? = nil

    // MARK: - Global Incoming Call State
    @Published var incomingCall: IncomingCallData? = nil
    @Published var inActiveCall: Bool = false
    @Published var isAnsweredFromCallKit: Bool = false

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
        if let savedToken = UserDefaults.standard.string(forKey: "jwt_token") {
            self.token = savedToken
        }
        if let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(CurrentUser.self, from: userData) {
            self.currentUser = user
        }

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

        // Regular push token — save for elder users so reminder pushes are deliverable.
        // Children use VoIP tokens (handled by VoIPManager) for call alerts instead.
        pushTokenObserver = NotificationCenter.default
            .publisher(for: .pushTokenRegistered)
            .compactMap { $0.object as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pushToken in
                self?.pendingPushToken = pushToken
                if self?.isElder == true { self?.savePushToken(pushToken) }
            }
    }

    // MARK: - Push token

    private func savePushToken(_ pushToken: String) {
        guard let authToken = token,
              let url = URL(string: "\(AppConfig.baseURL)/auth/apns-token") else { return }
        Task {
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["apnsToken": pushToken])
            _ = try? await URLSession.shared.data(for: req)
            print("✅ Regular push token saved for elder")
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
        // If elder just logged in and we already have the push token, send it now
        if user.role == "elder", let pushToken = pendingPushToken {
            savePushToken(pushToken)
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
