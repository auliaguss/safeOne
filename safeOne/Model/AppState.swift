//
//  AppState.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//


import Foundation
import Combine

class AppState: ObservableObject {
    @Published var elders: [Elder] = [
        Elder(name: "Sukarni"),
        Elder(name: "Joko")
    ]

    @Published var reminders: [Reminder] = [
        Reminder(
            title: "Vitamin D",
            notes: "1 Tablet",
            date: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
            repeatOption: .everyday,
            earlyReminder: .inTime,
            category: .medication,
            isCompleted: true,
            completedCount: 1,
            totalCount: 1,
            elderID: UUID(),
            imageName: "💊"
        ),
        Reminder(
            title: "Doctor Appointment",
            notes: "",
            date: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
            repeatOption: .none,
            earlyReminder: .none,
            category: .appointment,
            isCompleted: false,
            completedCount: 0,
            totalCount: 1,
            elderID: UUID(),
            imageName: "🩺"
        ),
        Reminder(
            title: "Antibiotics",
            notes: "",
            date: Calendar.current.date(bySettingHour: 9, minute: 5, second: 0, of: Date())!,
            repeatOption: .everyday,
            earlyReminder: .none,
            category: .medication,
            isCompleted: false,
            completedCount: 1,
            totalCount: 2,
            elderID: UUID(),
            imageName: "💊"
        ),
        Reminder(
            title: "Paracetamol",
            notes: "",
            date: Calendar.current.date(bySettingHour: 9, minute: 6, second: 0, of: Date())!,
            repeatOption: .everyday,
            earlyReminder: .none,
            category: .medication,
            isCompleted: false,
            completedCount: 1,
            totalCount: 2,
            elderID: UUID(),
            imageName: "💊"
        )
    ]

    @Published var selectedElderIndex: Int = 0

    var selectedElder: Elder? {
        guard elders.indices.contains(selectedElderIndex) else { return nil }
        return elders[selectedElderIndex]
    }

    func addReminder(_ reminder: Reminder) {
        reminders.append(reminder)
    }

    func todayReminders(for elder: Elder?) -> [Reminder] {
        guard elder != nil else { return [] }
        let cal = Calendar.current
        return reminders.filter { cal.isDateInToday($0.date) && !$0.isPast }
    }
}
