import AVFoundation
import AudioToolbox
import Foundation
import UIKit

@MainActor
final class ReminderAlertCoordinator {
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var alertedReminderIDs: Set<UUID> = []

    func processDueReminders(_ reminders: [Reminder], preferences: NotificationPreferences) -> Reminder? {
        let now = Date()
        let dueReminders = reminders.filter { reminder in
            !reminder.isCompleted
                && !alertedReminderIDs.contains(reminder.id)
                && now >= reminder.alertDate
                && now.timeIntervalSince(reminder.alertDate) <= 10
        }

        for reminder in dueReminders {
            alertedReminderIDs.insert(reminder.id)
            triggerAlert(for: reminder, preferences: preferences)
            return reminder
        }

        return nil
    }

    func resetAlertState(for reminderID: UUID) {
        alertedReminderIDs.remove(reminderID)
    }

    func markCompleted(_ reminderID: UUID) {
        alertedReminderIDs.insert(reminderID)
    }

    private func triggerAlert(for reminder: Reminder, preferences: NotificationPreferences) {
        if preferences.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }

        switch preferences.sound {
        case .none:
            break
        case .default, .gentle, .urgent:
            AudioServicesPlaySystemSound(SystemSoundID(1005))
        }

        if preferences.textToSpeechEnabled {
            let utterance = AVSpeechUtterance(string: spokenText(for: reminder))
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            speechSynthesizer.speak(utterance)
        }
    }

    private func spokenText(for reminder: Reminder) -> String {
        if reminder.notes.isEmpty {
            return reminder.title
        }

        return "\(reminder.title). \(reminder.notes)"
    }
}
