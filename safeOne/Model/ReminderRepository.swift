//
//  ReminderRepository.swift
//  safeOne
//

import Foundation

struct ReminderRepository {
    private static let base = AppConfig.baseURL

    // MARK: - Fetch

    static func fetchElders(token: String) async throws -> [ElderItem] {
        let req = try makeRequest("\(base)/users/me/elders", token: token)
        let (data, res) = try await URLSession.shared.data(for: req)
        try checkStatus(res, data: data)
        return try JSONDecoder().decode([ElderItem].self, from: data)
    }

    static func fetchReminders(elderId: String? = nil, date: Date? = nil, token: String) async throws -> [APIReminder] {
        var comps = URLComponents(string: "\(base)/reminders")!
        var items: [URLQueryItem] = []
        if let d = date {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            items.append(URLQueryItem(name: "date", value: fmt.string(from: d)))
        }
        if let id = elderId { items.append(URLQueryItem(name: "elderId", value: id)) }
        comps.queryItems = items.isEmpty ? nil : items
        let req = try makeRequest(comps.url!.absoluteString, token: token)
        let (data, res) = try await URLSession.shared.data(for: req)
        try checkStatus(res, data: data)
        return try JSONDecoder().decode([APIReminder].self, from: data)
    }

    static func fetchReminder(id: String, token: String) async throws -> APIReminder {
        let req = try makeRequest("\(base)/reminders/\(id)", token: token)
        let (data, res) = try await URLSession.shared.data(for: req)
        try checkStatus(res, data: data)
        return try JSONDecoder().decode(APIReminder.self, from: data)
    }

    // MARK: - CRUD

    static func createReminder(_ body: [String: Any], token: String) async throws -> APIReminder {
        var req = try makeRequest("\(base)/reminders", token: token, method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await URLSession.shared.data(for: req)
        try checkStatus(res, data: data)
        return try JSONDecoder().decode(APIReminder.self, from: data)
    }

    static func updateReminder(id: String, _ body: [String: Any], token: String) async throws -> APIReminder {
        var req = try makeRequest("\(base)/reminders/\(id)", token: token, method: "PATCH")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await URLSession.shared.data(for: req)
        try checkStatus(res, data: data)
        return try JSONDecoder().decode(APIReminder.self, from: data)
    }

    static func deleteReminder(id: String, token: String) async throws {
        let req = try makeRequest("\(base)/reminders/\(id)", token: token, method: "DELETE")
        let (data, res) = try await URLSession.shared.data(for: req)
        try checkStatus(res, data: data)
    }

    // MARK: - Elder Actions

    static func markDone(id: String, token: String) async throws -> APIReminder {
        let req = try makeRequest("\(base)/reminders/\(id)/done", token: token, method: "POST")
        let (data, res) = try await URLSession.shared.data(for: req)
        try checkStatus(res, data: data)
        return try JSONDecoder().decode(APIReminder.self, from: data)
    }

    static func snoozeReminder(id: String, token: String) async throws {
        let req = try makeRequest("\(base)/reminders/\(id)/snooze", token: token, method: "POST")
        let (data, res) = try await URLSession.shared.data(for: req)
        try checkStatus(res, data: data)
    }

    // MARK: - Helpers

    /// Throws a descriptive error when the server returns a non-2xx status.
    /// Extracts the `"error"` field from the JSON body when present so the
    /// message shown to the user is the real server reason, not a decode failure.
    private static func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let serverMsg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(http.statusCode)"
            throw NSError(
                domain: "APIError",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: serverMsg]
            )
        }
    }

    private static func makeRequest(_ urlString: String, token: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }
}
