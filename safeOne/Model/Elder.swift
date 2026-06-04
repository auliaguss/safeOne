import Foundation

struct Elder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var avatar: String?

    init(id: UUID = UUID(), name: String, avatar: String? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
    }
}

struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID
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

    init(
        id: UUID = UUID(),
        title: String,
        notes: String,
        date: Date,
        repeatOption: RepeatOption,
        earlyReminder: EarlyReminderOption,
        category: ReminderCategory,
        isCompleted: Bool = false,
        completedCount: Int = 0,
        totalCount: Int = 1,
        elderID: UUID,
        isPast: Bool = false,
        imageName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.date = date
        self.repeatOption = repeatOption
        self.earlyReminder = earlyReminder
        self.category = category
        self.isCompleted = isCompleted
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.elderID = elderID
        self.isPast = isPast
        self.imageName = imageName
    }
}

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
}

enum ReminderCategory: String, CaseIterable, Codable {
    case none = "None"
    case reminders = "Reminders"
    case medication = "Medication"
    case appointment = "Appointment"
    case exercise = "Exercise"
}
