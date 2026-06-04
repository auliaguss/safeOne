import Foundation

struct ReminderFilter {
    var date: Date?
    var startDate: Date?
    var endDate: Date?
    var userID: UUID?
}

final class ReminderService {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func getReminders(filter: ReminderFilter, token: String?) async throws -> [Reminder] {
        var queryItems: [URLQueryItem] = []
        let formatter = ISO8601DateFormatter()

        if let date = filter.date {
            queryItems.append(URLQueryItem(name: "date", value: formatter.string(from: date)))
        }

        if let startDate = filter.startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: startDate)))
        }

        if let endDate = filter.endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: endDate)))
        }

        if let userID = filter.userID {
            queryItems.append(URLQueryItem(name: "userId", value: userID.uuidString))
        }

        return try await apiClient.request(
            "reminders",
            token: token,
            queryItems: queryItems
        )
    }

    func addReminder(_ reminder: Reminder, token: String?) async throws -> Reminder {
        try await apiClient.request(
            "reminders",
            method: "POST",
            token: token,
            body: reminder
        )
    }

    func editReminder(_ reminder: Reminder, token: String?) async throws -> Reminder {
        try await apiClient.request(
            "reminders/\(reminder.id.uuidString)",
            method: "PUT",
            token: token,
            body: reminder
        )
    }

    func deleteReminders(ids: [UUID], token: String?) async throws {
        let request = DeleteRemindersRequest(ids: ids)
        let _: EmptyResponse = try await apiClient.request(
            "reminders",
            method: "DELETE",
            token: token,
            body: request
        )
    }
}

private struct DeleteRemindersRequest: Codable {
    var ids: [UUID]
}

