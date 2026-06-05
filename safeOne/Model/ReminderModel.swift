//
//  ReminderModel.swift
//  safeOne
//

import Foundation

// MARK: - Completion Log

struct CompletionLog: Codable, Identifiable {
    let id: String
    let completedAt: String
    let wasOnTime: Bool

    var formattedDate: String {
        // Try with fractional seconds first (PostgreSQL default)
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let d = withFrac.date(from: completedAt) ?? plain.date(from: completedAt) else {
            return completedAt
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM yyyy, HH:mm"
        return fmt.string(from: d)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case completedAt = "completed_at"
        case wasOnTime   = "was_on_time"
    }
}

// MARK: - API Reminder

struct APIReminder: Codable, Identifiable {
    let id: String
    let elderId: String?
    let title: String
    let notes: String?
    let date: String
    let repeatOption: String
    let earlyReminder: String?
    let category: String?
    let isCompleted: Bool
    let completedCount: Int
    let totalCount: Int
    let imageName: String?
    let completionLogs: [CompletionLog]?

    // PostgreSQL returns millisecond timestamps; try with .withFractionalSeconds first
    static func parseDate(_ string: String) -> Date? {
        let withMs = ISO8601DateFormatter()
        withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withMs.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    var isPast: Bool {
        guard let d = Self.parseDate(date) else { return false }
        return d < Date()
    }

    var formattedTime: String {
        guard let d = Self.parseDate(date) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: d)
    }

    var subtitleString: String {
        guard let d = Self.parseDate(date) else { return "" }
        let fmt = DateFormatter()
        let repeats = repeatOption == "everyday" || repeatOption.hasPrefix("days:")
        if repeats {
            fmt.dateFormat = "HH.mm"
            return "\(repeatDisplayName), \(fmt.string(from: d))"
        }
        fmt.dateFormat = "d MMM, HH.mm"
        return fmt.string(from: d)
    }

    var repeatDisplayName: String {
        switch repeatOption.lowercased() {
        case "none":     return "Never"
        case "everyday": return "Every day"
        case "weekly":   return "Weekly"
        case "monthly":  return "Monthly"
        default:
            if repeatOption.hasPrefix("days:") {
                let nums = repeatOption.dropFirst(5).split(separator: ",").compactMap { Int($0) }
                let names = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                let labels = nums.sorted().compactMap { (0...6).contains($0) ? names[$0] : nil }
                return labels.joined(separator: ", ")
            }
            return repeatOption.capitalized
        }
    }

    var statusText: String {
        guard let d = Self.parseDate(date) else { return "" }
        let now = Date()
        if d < now { return "Past" }
        let mins = Int(d.timeIntervalSince(now) / 60)
        if mins < 60 { return "in \(mins) min\(mins == 1 ? "" : "s")" }
        let hours = mins / 60
        return "in \(hours) hour\(hours == 1 ? "" : "s")"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, date, category
        case elderId        = "elder_id"
        case repeatOption   = "repeat_option"
        case earlyReminder  = "early_reminder"
        case isCompleted    = "is_completed"
        case completedCount = "completed_count"
        case totalCount     = "total_count"
        case imageName      = "image_name"
        case completionLogs = "completion_logs"
    }
}

// MARK: - Elder Item

struct ElderItem: Codable, Identifiable {
    let id: String
    let name: String
    let avatar: String?
}
