import Foundation

struct ReminderProgressSummary: Equatable {
    var completed: Int
    var total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

