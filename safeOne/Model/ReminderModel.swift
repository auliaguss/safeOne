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
    let date: String           // start date (ISO-8601 timestamp)
    let endDate: String?       // optional end date ("yyyy-MM-dd")
    let times: [String]?       // scheduled times per day e.g. ["09:00","15:00"]
    let repeatOption: String
    let earlyReminder: String?
    let category: String?
    let isCompleted: Bool
    let completedCount: Int
    let totalCount: Int
    let imageName: String?
    let completionLogs: [CompletionLog]?

    // MARK: - Parsing

    /// Handles "2026-06-05T09:00:00Z" and "2026-06-05T09:00:00.000Z"
    static func parseDate(_ string: String) -> Date? {
        let withMs = ISO8601DateFormatter()
        withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withMs.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    /// Handles DATE-only "yyyy-MM-dd" strings returned from the end_date column
    static func parseEndDate(_ string: String) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df.date(from: string) ?? parseDate(string)
    }

    // MARK: - Computed

    /// Times to display (falls back to the time embedded in `date`)
    var timesText: String {
        let t = (times ?? []).filter { !$0.isEmpty }
        if !t.isEmpty {
            return t.map { $0.replacingOccurrences(of: ":", with: ".") }.joined(separator: " | ")
        }
        guard let d = Self.parseDate(date) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH.mm"
        return fmt.string(from: d)
    }

    var isPast: Bool {
        // If end_date is set, "past" means end_date < today
        if let ed = endDate, !ed.isEmpty, let d = Self.parseEndDate(ed) {
            return d < Calendar.current.startOfDay(for: Date())
        }
        guard let d = Self.parseDate(date) else { return false }
        return d < Date()
    }

    var formattedTime: String {
        guard let d = Self.parseDate(date) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: d)
    }

    /// Subtitle shown in list rows (Image 5 format)
    var subtitleString: String {
        // Has end date → "Until 26 May, 09.00 | 18.00"
        if let edStr = endDate, !edStr.isEmpty, let ed = Self.parseEndDate(edStr) {
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "d MMM"
            return "Until \(dateFmt.string(from: ed)), \(timesText)"
        }
        // Everyday repeat (legacy) → "Everyday, 09.00"
        if repeatOption == "everyday" || repeatOption.hasPrefix("days:") {
            return "\(repeatDisplayName), \(timesText)"
        }
        // Single date → "26 May, 14.00"
        guard let d = Self.parseDate(date) else { return timesText }
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "d MMM"
        return "\(dateFmt.string(from: d)), \(timesText)"
    }

    var repeatDisplayName: String {
        switch repeatOption.lowercased() {
        case "none":     return "Never"
        case "everyday": return "Everyday"
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
        case id, title, notes, date, category, times
        case elderId        = "elder_id"
        case endDate        = "end_date"
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
