//
//  ReminderViewModel.swift
//  safeOne
//

import Foundation
import Combine

class ReminderViewModel: ObservableObject {
    @Published var reminders: [APIReminder] = []
    @Published var tomorrowReminders: [APIReminder] = []
    @Published var elders: [ElderItem] = []
    @Published var selectedElderId: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // Child-side computed sections (time-based)
    var activeReminders: [APIReminder] { reminders.filter { !$0.isPast } }
    var pastReminders: [APIReminder]   { reminders.filter { $0.isPast } }

    // MARK: - Child

    @MainActor
    func loadForChild(token: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            elders = try await ReminderRepository.fetchElders(token: token)
            if selectedElderId == nil { selectedElderId = elders.first?.id }
            if let id = selectedElderId {
                reminders = try await ReminderRepository.fetchReminders(elderId: id, token: token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func selectElder(_ id: String, token: String) async {
        selectedElderId = id
        do {
            reminders = try await ReminderRepository.fetchReminders(elderId: id, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Elder

    @MainActor
    func loadForElder(token: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            reminders = try await ReminderRepository.fetchReminders(token: token)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            tomorrowReminders = (try? await ReminderRepository.fetchReminders(date: tomorrow, token: token)) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Shared refresh

    @MainActor
    func fetchReminders(token: String) async {
        guard !token.isEmpty else { return }
        do {
            if let id = selectedElderId {
                reminders = try await ReminderRepository.fetchReminders(elderId: id, token: token)
            } else {
                reminders = try await ReminderRepository.fetchReminders(token: token)
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                tomorrowReminders = (try? await ReminderRepository.fetchReminders(date: tomorrow, token: token)) ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Actions

    @MainActor
    func markDone(id: String, token: String) async {
        do {
            let updated = try await ReminderRepository.markDone(id: id, token: token)
            if let idx = reminders.firstIndex(where: { $0.id == id }) {
                reminders[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func snooze(id: String, token: String) async {
        do {
            try await ReminderRepository.snoozeReminder(id: id, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func delete(id: String, token: String) async {
        // Step 5.2 — Optimistic: remove immediately, rollback on failure
        let backup = reminders
        reminders.removeAll { $0.id == id }
        do {
            try await ReminderRepository.deleteReminder(id: id, token: token)
        } catch {
            reminders = backup
            errorMessage = "Couldn't delete reminder. Please try again."
        }
    }
}
