//
//  Elder.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//

import Foundation

// MARK: - Elder

struct Elder: Identifiable {
    let id = UUID()
    var name: String
    var avatar: String?
}

// MARK: - Reminder

struct Reminder: Identifiable {
    let id = UUID()
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
    var isPast: Bool = false
    var imageName: String?
}

// MARK: - Enums

enum RepeatOption: String, CaseIterable {
    case none = "None"
    case everyday = "Everyday"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

enum EarlyReminderOption: String, CaseIterable {
    case none = "None"
    case inTime = "In Time"
    case fiveMin = "5 Minutes Before"
    case tenMin = "10 Minutes Before"
    case thirtyMin = "30 Minutes Before"
}

enum ReminderCategory: String, CaseIterable {
    case none = "None"
    case reminders = "Reminders"
    case medication = "Medication"
    case appointment = "Appointment"
    case exercise = "Exercise"
}
