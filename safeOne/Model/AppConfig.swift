//
//  AppConfig.swift
//  safeOne
//


import Foundation

enum AppConfig {
    static let maximumCallDurationInSeconds = 60
    static let maximumDailyEmergencyCalls = 3

    // Free-plan limits. Premium lifts them (see SubscriptionManager).
    static let freeReminderLimitPerElder = 5
    static let freeElderLimit = 1
    static let freeCaregiverLimit = 1
    static let premiumCaregiverLimit = 10

    static let baseURL: String = {
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: "API_BASE_URL"
        ) as? String else {
            fatalError("API_BASE_URL belum dikonfigurasi")
        }

        return value
    }()

    static let appID: String = {
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: "APP_ID"
        ) as? String else {
            fatalError("APP_ID belum dikonfigurasi")
        }

        return value
    }()
}
