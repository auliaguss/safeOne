import SwiftUI

struct ReminderDetailView: View {
    let reminder: Reminder

    var body: some View {
        AddReminderView(reminder: reminder)
    }
}

#Preview {
    NavigationStack {
        ReminderDetailView(reminder: Reminder(
            title: "Vitamin D",
            notes: "1 Tablet",
            date: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
            repeatOption: .everyday,
            earlyReminder: .inTime,
            category: .medication,
            elderID: UUID(),
            imageName: "💊"
        ))
    }
}
