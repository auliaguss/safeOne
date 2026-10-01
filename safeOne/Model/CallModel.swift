//
//  CallModel.swift
//  safeOne
//
//  Created by Ivan Yuantama Pradipta on 03/06/26.
//

import Foundation

struct InitiateCallResponse: Codable {
    let callId: String
    let channelName: String
    let agoraToken: String
    let agoraAppId: String
}

struct AnswerCallResponse: Codable {
    let callId: String
    let channelName: String
    let agoraToken: String
    let agoraAppId: String
    let elderName: String
}

enum ElderEmergencyCallQuota {
    private static let dateKeyPrefix = "elderEmergencyCallQuotaDate"
    private static let countKeyPrefix = "elderEmergencyCallQuotaCount"

    static func callsUsedToday(
        for userID: String,
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) -> Int {
        guard let recordedDate = defaults.object(forKey: dateKey(for: userID)) as? Date,
              calendar.isDate(recordedDate, inSameDayAs: now) else {
            return 0
        }

        return min(
            max(defaults.integer(forKey: countKey(for: userID)), 0),
            AppConfig.maximumDailyEmergencyCalls
        )
    }

    static func canStartCall(
        for userID: String,
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) -> Bool {
        callsUsedToday(
            for: userID,
            now: now,
            defaults: defaults,
            calendar: calendar
        ) < AppConfig.maximumDailyEmergencyCalls
    }

    @discardableResult
    static func recordSuccessfulCall(
        for userID: String,
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) -> Int {
        let updatedCount = min(
            callsUsedToday(
                for: userID,
                now: now,
                defaults: defaults,
                calendar: calendar
            ) + 1,
            AppConfig.maximumDailyEmergencyCalls
        )

        defaults.set(now, forKey: dateKey(for: userID))
        defaults.set(updatedCount, forKey: countKey(for: userID))
        return updatedCount
    }

    private static func dateKey(for userID: String) -> String {
        "\(dateKeyPrefix).\(userID)"
    }

    private static func countKey(for userID: String) -> String {
        "\(countKeyPrefix).\(userID)"
    }
}
