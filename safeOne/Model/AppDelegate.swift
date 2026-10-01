//
//  AppDelegate.swift
//  safeOne
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    // Called by iOS after registerForRemoteNotifications() succeeds.
    // This is the REGULAR push token (not the VoIP/PushKit token).
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationCenter.default.post(name: .pushTokenRegistered, object: token)
        print("📲 Regular push token received: \(token.prefix(20))...")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
