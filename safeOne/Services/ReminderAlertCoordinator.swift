import AVFoundation
import AudioToolbox
import Foundation
import UIKit

@MainActor
final class ReminderAlertCoordinator {
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var alertedReminderIDs: Set<UUID> = []

    func processDueReminders(_ reminders: [Reminder], preferences: NotificationPreferences) {
        let now = Date()
        let dueReminders = reminders.filter { reminder in
            !reminder.isCompleted
                && !alertedReminderIDs.contains(reminder.id)
                && abs(reminder.date.timeIntervalSince(now)) <= 30
        }

        for reminder in dueReminders {
            alertedReminderIDs.insert(reminder.id)
            triggerAlert(for: reminder, preferences: preferences)
        }
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
            let utterance = AVSpeechUtterance(string: reminder.title)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            speechSynthesizer.speak(utterance)
        }
    }
}

