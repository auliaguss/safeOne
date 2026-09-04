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
        fmt.locale = Locale(identifier: AppLanguage.current.localeIdentifier)
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

    /// Times to display in local timezone. Stored as UTC "HH:mm"; converted to local for display.
    var timesText: String {
        let t = (times ?? []).filter { !$0.isEmpty }
        if !t.isEmpty {
            let utcFmt = DateFormatter()
            utcFmt.timeZone = TimeZone(abbreviation: "UTC")
            utcFmt.dateFormat = "HH:mm"
            let localFmt = DateFormatter()
            localFmt.dateFormat = "HH.mm"
            let labels = t.compactMap { str -> String? in
                guard let d = utcFmt.date(from: str) else { return nil }
                return localFmt.string(from: d)
            }
            if !labels.isEmpty { return labels.joined(separator: " | ") }
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
            dateFmt.locale = Locale(identifier: AppLanguage.current.localeIdentifier)
            return AppLanguage.localized("Hingga \(dateFmt.string(from: ed)), \(timesText)", "Until \(dateFmt.string(from: ed)), \(timesText)")
        }
        // Everyday repeat (legacy) → "Everyday, 09.00"
        if repeatOption == "everyday" || repeatOption.hasPrefix("days:") {
            return "\(repeatDisplayName), \(timesText)"
        }
        // Single date → "26 May, 14.00"
        guard let d = Self.parseDate(date) else { return timesText }
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: AppLanguage.current.localeIdentifier)
        dateFmt.dateFormat = "d MMM"
        return "\(dateFmt.string(from: d)), \(timesText)"
    }

    var repeatDisplayName: String {
        switch repeatOption.lowercased() {
        case "none":     return AppLanguage.localized("Tidak pernah", "Never")
        case "everyday": return AppLanguage.localized("Setiap hari", "Everyday")
        case "weekly":   return AppLanguage.localized("Mingguan", "Weekly")
        case "monthly":  return AppLanguage.localized("Bulanan", "Monthly")
        default:
            if repeatOption.hasPrefix("days:") {
                let nums = repeatOption.dropFirst(5).split(separator: ",").compactMap { Int($0) }
                let names = AppLanguage.current == .indonesian
                    ? ["Min","Sen","Sel","Rab","Kam","Jum","Sab"]
                    : ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                let labels = nums.sorted().compactMap { (0...6).contains($0) ? names[$0] : nil }
                return labels.joined(separator: ", ")
            }
            return repeatOption.capitalized
        }
    }

    var statusText: String {
        guard let d = Self.parseDate(date) else { return "" }
        let now = Date()
        if d < now { return AppLanguage.localized("Lewat", "Past") }
        let mins = Int(d.timeIntervalSince(now) / 60)
        if mins < 60 { return AppLanguage.localized("dalam \(mins) menit", "in \(mins) min\(mins == 1 ? "" : "s")") }
        let hours = mins / 60
        return AppLanguage.localized("dalam \(hours) jam", "in \(hours) hour\(hours == 1 ? "" : "s")")
    }

    var localizedCategory: String {
        switch category?.lowercased() {
        case "medication": return AppLanguage.localized("Obat", "Medication")
        case "appointment": return AppLanguage.localized("Janji temu", "Appointment")
        case "exercise": return AppLanguage.localized("Olahraga", "Exercise")
        case "reminders": return AppLanguage.localized("Pengingat", "Reminders")
        case "none", nil, "": return AppLanguage.localized("Tidak ada", "None")
        default: return category?.capitalized ?? ""
        }
    }

    var localizedEarlyReminder: String {
        switch earlyReminder?.lowercased() {
        case "in_time", nil, "none": return AppLanguage.localized("Tepat waktu", "On time")
        case "5_minutes_before": return AppLanguage.localized("5 menit sebelumnya", "5 minutes before")
        case "10_minutes_before": return AppLanguage.localized("10 menit sebelumnya", "10 minutes before")
        case "30_minutes_before": return AppLanguage.localized("30 menit sebelumnya", "30 minutes before")
        default: return earlyReminder?.replacingOccurrences(of: "_", with: " ").capitalized ?? ""
        }
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        elderId = try container.decodeIfPresent(String.self, forKey: .elderId)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        date = try container.decode(String.self, forKey: .date)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        times = try container.decodeIfPresent([String].self, forKey: .times)
        repeatOption = try container.decode(String.self, forKey: .repeatOption)
        earlyReminder = try container.decodeIfPresent(String.self, forKey: .earlyReminder)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)

        // PATCH /reminders/:id is allowed to return only the reminder columns
        // documented by the backend, which do not include progress fields.
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedCount = try container.decodeIfPresent(Int.self, forKey: .completedCount) ?? 0
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount)
            ?? max(times?.count ?? 0, 1)
        completionLogs = try container.decodeIfPresent([CompletionLog].self, forKey: .completionLogs)
    }
}

// MARK: - Elder Item

struct ElderItem: Codable, Identifiable {
    let id: String
    let name: String
    let avatar: String?
}
