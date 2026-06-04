//
//  AppPersistence.swift
//  safeOne
//

import Foundation

struct AppSnapshot: Codable {
    var elders: [Elder]
    var reminders: [Reminder]
    var selectedElderIndex: Int
}

struct AppPersistence {
    static let shared = AppPersistence()

    private let defaults = UserDefaults.standard
    private let snapshotKey = "safeOne.snapshot"

    func loadSnapshot() -> AppSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: AppSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}
