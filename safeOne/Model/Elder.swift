//
//  Elder.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import Foundation

// MARK: - Elder

struct Elder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var avatar: String?
}

// MARK: - Reminder

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var notes: String
    var date: Date
    var repeatOption: RepeatOption
    var earlyReminder: EarlyReminderOption
    var category: ReminderCategory
    var isCompleted: Bool = false
    var completedCount: Int = 0
    var totalCount: Int = 1
    var elderID: UUID
    var imageName: String?

    var isPast: Bool {
        nextOccurrence(after: Date()) == nil
    }

    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let scheduledDay = calendar.startOfDay(for: date)
        let targetDay = calendar.startOfDay(for: day)

        guard targetDay >= scheduledDay else { return false }

        switch repeatOption {
        case .none:
            return calendar.isDate(date, inSameDayAs: day)
        case .everyday:
            return true
        case .weekly:
            return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: day)
        case .monthly:
            return calendar.component(.day, from: date) == calendar.component(.day, from: day)
        }
    }

    func nextOccurrence(after reference: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch repeatOption {
        case .none:
            return date >= reference ? date : nil
        case .everyday:
            return nextRepeatingOccurrence(
                after: reference,
                calendar: calendar,
                components: calendar.dateComponents([.hour, .minute], from: date)
            )
        case .weekly:
            return nextRepeatingOccurrence(
                after: reference,
                calendar: calendar,
                components: calendar.dateComponents([.weekday, .hour, .minute], from: date)
            )
        case .monthly:
            return nextRepeatingOccurrence(
                after: reference,
                calendar: calendar,
                components: calendar.dateComponents([.day, .hour, .minute], from: date)
            )
        }
    }

    private func nextRepeatingOccurrence(
        after reference: Date,
        calendar: Calendar,
        components: DateComponents
    ) -> Date? {
        let searchStart = reference < date ? date.addingTimeInterval(-1) : reference.addingTimeInterval(-1)
        return calendar.nextDate(
            after: searchStart,
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }
}

// MARK: - Enums

enum RepeatOption: String, CaseIterable, Codable {
    case none = "None"
    case everyday = "Everyday"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

enum EarlyReminderOption: String, CaseIterable, Codable {
    case none = "None"
    case inTime = "In Time"
    case fiveMin = "5 Minutes Before"
    case tenMin = "10 Minutes Before"
    case thirtyMin = "30 Minutes Before"

    var minutesBefore: Int? {
        switch self {
        case .none, .inTime:
            return nil
        case .fiveMin:
            return 5
        case .tenMin:
            return 10
        case .thirtyMin:
            return 30
        }
    }
}

enum ReminderCategory: String, CaseIterable, Codable {
    case none = "None"
    case reminders = "Reminders"
    case medication = "Medication"
    case appointment = "Appointment"
    case exercise = "Exercise"
}
