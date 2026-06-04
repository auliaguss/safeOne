//
//  ReminderNotificationManager.swift
//  safeOne
//

import Foundation
import UserNotifications

enum ReminderNotificationAction {
    case markDone(UUID)
}

final class ReminderNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderNotificationManager()

    var actionHandler: ((ReminderNotificationAction) -> Void)?

    private let center = UNUserNotificationCenter.current()
    private let categoryIdentifier = "safeone.reminder"
    private let doneActionIdentifier = "safeone.done"
    private let snoozeActionIdentifier = "safeone.snooze"

    private enum UserInfoKey {
        static let reminderID = "reminderID"
        static let reminderTitle = "reminderTitle"
        static let reminderNotes = "reminderNotes"
        static let elderName = "elderName"
    }

    private override init() {
        super.init()
    }

    func configure() {
        center.delegate = self
        registerCategories()
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .ephemeral, .provisional:
            return true
        case .notDetermined:
            do {
                return try await requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func syncNotifications(for reminders: [Reminder], elders: [Elder]) async {
        guard await requestAuthorizationIfNeeded() else { return }

        let elderNamesByID = Dictionary(uniqueKeysWithValues: elders.map { ($0.id, $0.name) })

        for reminder in reminders {
            removeNotifications(for: reminder.id)

            guard shouldSchedule(reminder) else { continue }
            let elderName = elderNamesByID[reminder.elderID]

            do {
                try await add(makePrimaryRequest(for: reminder, elderName: elderName))

                if let earlyRequest = makeEarlyReminderRequest(for: reminder, elderName: elderName) {
                    try await add(earlyRequest)
                }
            } catch {
                continue
            }
        }
    }

    func scheduleSnooze(for reminder: Reminder, elderName: String?) async {
        guard await requestAuthorizationIfNeeded() else { return }

        do {
            try await add(makeSnoozeRequest(for: reminder, elderName: elderName))
        } catch {
            return
        }
    }

    private func shouldSchedule(_ reminder: Reminder) -> Bool {
        if reminder.repeatOption == .none && reminder.isCompleted {
            return false
        }

        return reminder.nextOccurrence(after: Date()) != nil
    }

    private func registerCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: "Snooze 10m",
            options: []
        )
        let doneAction = UNNotificationAction(
            identifier: doneActionIdentifier,
            title: "Done",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [doneAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    private func makePrimaryRequest(for reminder: Reminder, elderName: String?) -> UNNotificationRequest {
        let content = notificationContent(
            for: reminder,
            elderName: elderName,
            bodyPrefix: "It's time now."
        )
        let trigger = trigger(for: reminder, offsetMinutes: 0)

        return UNNotificationRequest(
            identifier: identifier(for: reminder.id, kind: "main"),
            content: content,
            trigger: trigger
        )
    }

    private func makeEarlyReminderRequest(for reminder: Reminder, elderName: String?) -> UNNotificationRequest? {
        guard let leadTime = reminder.earlyReminder.minutesBefore else { return nil }

        let content = notificationContent(
            for: reminder,
            elderName: elderName,
            bodyPrefix: "Coming up in \(leadTime) minutes."
        )
        let trigger = trigger(for: reminder, offsetMinutes: leadTime)

        return UNNotificationRequest(
            identifier: identifier(for: reminder.id, kind: "early"),
            content: content,
            trigger: trigger
        )
    }

    private func makeSnoozeRequest(for reminder: Reminder, elderName: String?) -> UNNotificationRequest {
        let content = notificationContent(
            for: reminder,
            elderName: elderName,
            bodyPrefix: "Snoozed for 10 minutes."
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)

        return UNNotificationRequest(
            identifier: identifier(for: reminder.id, kind: "snooze"),
            content: content,
            trigger: trigger
        )
    }

    private func notificationContent(
        for reminder: Reminder,
        elderName: String?,
        bodyPrefix: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = elderName.map { "\($0): \(reminder.title)" } ?? reminder.title
        content.body = bodyText(for: reminder, prefix: bodyPrefix)
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            UserInfoKey.reminderID: reminder.id.uuidString,
            UserInfoKey.reminderTitle: reminder.title,
            UserInfoKey.reminderNotes: reminder.notes,
            UserInfoKey.elderName: elderName ?? ""
        ]
        return content
    }

    private func bodyText(for reminder: Reminder, prefix: String) -> String {
        if !reminder.notes.isEmpty {
            return "\(prefix) \(reminder.notes)"
        }

        if reminder.category != .none {
            return "\(prefix) \(reminder.category.rawValue)"
        }

        return prefix
    }

    private func trigger(for reminder: Reminder, offsetMinutes: Int) -> UNCalendarNotificationTrigger {
        let notificationDate = reminder.date.addingTimeInterval(TimeInterval(-offsetMinutes * 60))
        let calendar = Calendar.current
        let components: DateComponents
        let repeats: Bool

        switch reminder.repeatOption {
        case .none:
            components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
            repeats = false
        case .everyday:
            components = calendar.dateComponents([.hour, .minute], from: notificationDate)
            repeats = true
        case .weekly:
            components = calendar.dateComponents([.weekday, .hour, .minute], from: notificationDate)
            repeats = true
        case .monthly:
            components = calendar.dateComponents([.day, .hour, .minute], from: notificationDate)
            repeats = true
        }

        return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    }

    private func identifier(for reminderID: UUID, kind: String) -> String {
        "safeone.reminder.\(reminderID.uuidString).\(kind)"
    }

    private func removeNotifications(for reminderID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            identifier(for: reminderID, kind: "main"),
            identifier(for: reminderID, kind: "early"),
            identifier(for: reminderID, kind: "snooze")
        ])
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: options) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.actionIdentifier {
        case doneActionIdentifier:
            guard
                let rawID = response.notification.request.content.userInfo[UserInfoKey.reminderID] as? String,
                let reminderID = UUID(uuidString: rawID)
            else {
                return
            }

            await MainActor.run {
                actionHandler?(.markDone(reminderID))
            }
        case snoozeActionIdentifier:
            do {
                try await add(makeSnoozeRequest(from: response.notification.request))
            } catch {
                return
            }
        default:
            return
        }
    }

    private func makeSnoozeRequest(from request: UNNotificationRequest) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = request.content.title
        content.body = request.content.body
        content.sound = request.content.sound
        content.categoryIdentifier = request.content.categoryIdentifier
        content.userInfo = request.content.userInfo

        let reminderID = (request.content.userInfo[UserInfoKey.reminderID] as? String)
            .flatMap(UUID.init(uuidString:))
            ?? UUID()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)

        return UNNotificationRequest(
            identifier: identifier(for: reminderID, kind: "snooze"),
            content: content,
            trigger: trigger
        )
    }
}
