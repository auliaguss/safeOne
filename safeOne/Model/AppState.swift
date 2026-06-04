//
//  AppState.swift
//  ElderCareApp
//
//  Created by Hercio Venceslau Silla on 28/05/26.
//
import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var elders: [Elder] {
        didSet {
            clampSelectedElderIndex()
            persistState()
            syncReminderNotifications()
        }
    }
    
    @Published var reminders: [Reminder] {
        didSet {
            persistState()
            syncReminderNotifications()
        }
    }
    
    @Published var selectedElderIndex: Int {
        didSet {
            clampSelectedElderIndex()
            persistState()
        }
    }
    
    private let notificationManager: ReminderNotificationManager
    private let persistence: AppPersistence
    
    init(
        notificationManager: ReminderNotificationManager = .shared,
        persistence: AppPersistence = .shared
    ) {
        self.notificationManager = notificationManager
        self.persistence = persistence
        
        if let snapshot = persistence.loadSnapshot(), !snapshot.elders.isEmpty {
            elders = snapshot.elders
            reminders = snapshot.reminders
            selectedElderIndex = snapshot.selectedElderIndex
        } else {
            let defaultElders = Self.defaultElders
            elders = defaultElders
            reminders = Self.defaultReminders(for: defaultElders)
            selectedElderIndex = 0
        }
        
        notificationManager.configure()
        notificationManager.actionHandler = { [weak self] action in
            guard let self else { return }
            self.handleNotificationAction(action)
        }
        clampSelectedElderIndex()
        persistState()
        syncReminderNotifications()
    }
    
    var selectedElder: Elder? {
        guard elders.indices.contains(selectedElderIndex) else { return nil }
        return elders[selectedElderIndex]
    }
    
    func addReminder(_ reminder: Reminder) {
        reminders = sortByNextOccurrence(reminders + [reminder])
    }
    
    func addElder(named name: String) {
        elders.append(Elder(name: name))
    }
    
    func removeElders(atOffsets offsets: IndexSet) {
        let removedIDs = offsets.map { elders[$0].id }
        //        elders.remove(atOffsets: offsets)
        reminders.removeAll { removedIDs.contains($0.elderID) }
    }
    
    func selectElder(at index: Int) {
        guard elders.indices.contains(index) else { return }
        selectedElderIndex = index
    }
    
    func reminders(for elder: Elder?) -> [Reminder] {
        guard let elder else { return [] }
        return sortByNextOccurrence(reminders.filter { $0.elderID == elder.id })
    }
    
    func activeReminders(for elder: Elder?) -> [Reminder] {
        sortByNextOccurrence(reminders(for: elder).filter { !$0.isPast })
    }
    
    func pastReminders(for elder: Elder?) -> [Reminder] {
        reminders(for: elder)
            .filter { $0.isPast }
            .sorted { $0.date > $1.date }
    }
    
    func todayReminders(for elder: Elder?) -> [Reminder] {
        guard elder != nil else { return [] }
        return sortByNextOccurrence(reminders(for: elder).filter { $0.occurs(on: Date()) })
    }
    
    func acknowledgeReminder(_ reminderID: UUID) {
        guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else { return }
        guard reminders[index].repeatOption == .none else { return }
        
        reminders[index].isCompleted = true
        reminders[index].completedCount = reminders[index].totalCount
    }
    
    func snoozeReminder(_ reminderID: UUID) {
        guard let reminder = reminders.first(where: { $0.id == reminderID }) else { return }
        let elderName = elders.first(where: { $0.id == reminder.elderID })?.name
        
        Task {
            await notificationManager.scheduleSnooze(for: reminder, elderName: elderName)
        }
    }
    
    private func handleNotificationAction(_ action: ReminderNotificationAction) {
        switch action {
        case .markDone(let reminderID):
            acknowledgeReminder(reminderID)
        }
    }
    
    private func persistState() {
        persistence.saveSnapshot(
            AppSnapshot(
                elders: elders,
                reminders: reminders,
                selectedElderIndex: selectedElderIndex
            )
        )
    }
    
    private func syncReminderNotifications() {
        let reminders = reminders
        let elders = elders
        
        Task {
            await notificationManager.syncNotifications(for: reminders, elders: elders)
        }
    }
    
    private func clampSelectedElderIndex() {
        let clampedIndex = min(max(0, selectedElderIndex), max(0, elders.count - 1))
        if selectedElderIndex != clampedIndex {
            selectedElderIndex = clampedIndex
        }
    }
    
    private func sortByNextOccurrence(_ reminders: [Reminder]) -> [Reminder] {
        reminders.sorted { lhs, rhs in
            let lhsDate = lhs.nextOccurrence(after: Date()) ?? lhs.date
            let rhsDate = rhs.nextOccurrence(after: Date()) ?? rhs.date
            return lhsDate < rhsDate
        }
    }
    
    private static let defaultElders: [Elder] = [
        Elder(name: "Sukarni"),
        Elder(name: "Joko")
    ]
    
    private static func defaultReminders(for elders: [Elder]) -> [Reminder] {
        let primaryElderID = elders.first?.id ?? UUID()
        let secondaryElderID = elders.dropFirst().first?.id ?? primaryElderID
        
        return [
            Reminder(
                title: "Vitamin D",
                notes: "1 tablet after breakfast",
                date: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
                repeatOption: .everyday,
                earlyReminder: .tenMin,
                category: .medication,
                isCompleted: false,
                completedCount: 0,
                totalCount: 1,
                elderID: primaryElderID,
                imageName: "💊"
            ),
            Reminder(
                title: "Doctor Appointment",
                notes: "",
                date: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                repeatOption: .none,
                earlyReminder: .thirtyMin,
                category: .appointment,
                isCompleted: false,
                completedCount: 0,
                totalCount: 1,
                elderID: primaryElderID,
                imageName: "🩺"
            ),
            Reminder(
                title: "Antibiotics",
                notes: "1 tablet after dinner",
                date: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!,
                repeatOption: .everyday,
                earlyReminder: .fiveMin,
                category: .medication,
                isCompleted: false,
                completedCount: 0,
                totalCount: 1,
                elderID: secondaryElderID,
                imageName: "💊"
            ),
            Reminder(
                title: "Paracetamol",
                notes: "",
                date: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!,
                repeatOption: .everyday,
                earlyReminder: .none,
                category: .medication,
                isCompleted: false,
                completedCount: 1,
                totalCount: 2,
                elderID: primaryElderID,
                imageName: "💊"
            )
        ]
    }
}
