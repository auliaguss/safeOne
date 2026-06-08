import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(reminder: Reminder, preferences: NotificationPreferences) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.notes.isEmpty ? reminder.category.displayName : reminder.notes
        content.sound = notificationSound(for: preferences.sound)
        content.userInfo = [
            "reminderID": reminder.id.uuidString
        ]

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminder.alertDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleSnooze(for reminder: Reminder, minutes: Int = 5) async {
        var updated = reminder
        updated.date = Calendar.current.date(byAdding: .minute, value: minutes, to: reminder.date) ?? reminder.date
        await schedule(
            reminder: updated,
            preferences: NotificationPreferences(sound: .default, hapticsEnabled: true, textToSpeechEnabled: true)
        )
    }

    func cancel(reminderID: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID.uuidString])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderID.uuidString])
    }

    private func notificationSound(for sound: AlertSound) -> UNNotificationSound? {
        switch sound {
        case .none:
            return nil
        case .default, .gentle, .urgent:
            return .default
        }
    }
}
