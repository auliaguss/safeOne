//
//  NotificationManager.swift
//  safeOne
//

import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let reminderDeepLink   = Notification.Name("com.safeone.reminderDeepLink")
    static let reminderAlert      = Notification.Name("com.safeone.reminderAlert")
    static let pushTokenRegistered = Notification.Name("com.safeone.pushTokenRegistered")
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func setup() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // App in foreground — reminder shows full-screen; other notifications show banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if let data = extractReminderData(userInfo) {
            NotificationCenter.default.post(name: .reminderAlert, object: data)
            // Suppress banner — full-screen view replaces it
            completionHandler([.sound, .badge])
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    // User tapped a notification while app was in background / closed
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let data = extractReminderData(userInfo) {
            // Show full-screen view after app opens
            NotificationCenter.default.post(name: .reminderAlert, object: data)
        } else if let reminderId = userInfo["reminderId"] as? String {
            // Fallback: deep-link to reminder in dashboard
            NotificationCenter.default.post(name: .reminderDeepLink, object: reminderId)
        }
        completionHandler()
    }

    // MARK: - Helper

    private func extractReminderData(_ userInfo: [AnyHashable: Any]) -> ReminderNotificationData? {
        guard userInfo["type"] as? String == "reminder",
              let id    = userInfo["reminderId"] as? String,
              let title = userInfo["reminderTitle"] as? String
        else { return nil }

        return ReminderNotificationData(
            id:        id,
            title:     title,
            notes:     userInfo["reminderNotes"]    as? String,
            imageName: userInfo["reminderImage"]    as? String,
            time:      userInfo["reminderTime"]     as? String ?? "",
            category:  userInfo["reminderCategory"] as? String
        )
    }
}
