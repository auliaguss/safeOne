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
