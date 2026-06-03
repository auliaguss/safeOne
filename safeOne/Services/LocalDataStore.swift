import Foundation

struct LocalDataStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let remindersKey = "localReminders"
    private let eldersKey = "localElders"

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadReminders() -> [Reminder]? {
        guard let data = UserDefaults.standard.data(forKey: remindersKey) else { return nil }
        return try? decoder.decode([Reminder].self, from: data)
    }

    func saveReminders(_ reminders: [Reminder]) {
        guard let data = try? encoder.encode(reminders) else { return }
        UserDefaults.standard.set(data, forKey: remindersKey)
    }

    func loadElders() -> [Elder]? {
        guard let data = UserDefaults.standard.data(forKey: eldersKey) else { return nil }
        return try? decoder.decode([Elder].self, from: data)
    }

    func saveElders(_ elders: [Elder]) {
        guard let data = try? encoder.encode(elders) else { return }
        UserDefaults.standard.set(data, forKey: eldersKey)
    }
}

