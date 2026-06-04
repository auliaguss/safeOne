import Foundation
import Supabase
import UIKit

final class SupabaseRepository {
    static let shared = SupabaseRepository()

    private let client = SupabaseManager.shared.client

    // MARK: - Reminders

    func loadReminders(userID: UUID) async throws -> [Reminder] {
        let rows: [SupabaseReminderRow] = try await client.database
            .from("reminders")
            .select()
            .eq("elder_id", value: userID.uuidString)
            .execute()
            .value
        return rows.map(\.toModel)
    }

    func upsertReminder(_ reminder: Reminder, createdBy userID: UUID) async throws -> Reminder {
        let row = SupabaseReminderRow(model: reminder, createdBy: userID)
        let rows: [SupabaseReminderRow] = try await client.database
            .from("reminders")
            .upsert(row, onConflict: "id")
            .select()
            .execute()
            .value
        return rows.first?.toModel ?? reminder
    }

    func deleteReminders(ids: [UUID]) async throws {
        for id in ids {
            _ = try await client.database
                .from("reminders")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        }
    }

    // MARK: - Elders

    func loadElders(caregiverID: UUID) async throws -> [Elder] {
        let assignmentRows: [CaregiverAssignmentRow] = try await client.database
            .from("caregiver_assignments")
            .select()
            .eq("child_id", value: caregiverID.uuidString)
            .execute()
            .value

        var elders: [Elder] = []
        for assignment in assignmentRows {
            let elderRows: [SupabaseUserRow] = try await client.database
                .from("users")
                .select()
                .eq("id", value: assignment.elderID.uuidString)
                .limit(1)
                .execute()
                .value

            if let elder = elderRows.first, elder.role == .elder {
                elders.append(elder.toElder)
            }
        }
        return elders
    }

    func createElder(name: String, caregiverID: UUID) async throws -> Elder {
        let elder = Elder(name: name)

        let elderRow = SupabaseUserRow(
            id: elder.id,
            appleUserID: nil,
            name: elder.name,
            role: .elder,
            avatar: elder.avatar
        )

        _ = try await client.database
            .from("users")
            .insert(elderRow)
            .execute()

        let assignment = CaregiverAssignmentRow(childID: caregiverID, elderID: elder.id)
        _ = try await client.database
            .from("caregiver_assignments")
            .insert(assignment)
            .execute()

        return elder
    }

    func removeElderAssignments(ids: [UUID], caregiverID: UUID) async throws {
        for elderID in ids {
            _ = try await client.database
                .from("caregiver_assignments")
                .delete()
                .eq("child_id", value: caregiverID.uuidString)
                .eq("elder_id", value: elderID.uuidString)
                .execute()
        }
    }
}

// MARK: - Private Row Types

private struct SupabaseUserRow: Codable {
    var id: UUID
    var appleUserID: String?
    var name: String
    var role: UserRole
    var avatar: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case appleUserID = "apple_user_id"
        case name
        case role
        case avatar
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: UUID, appleUserID: String?, name: String, role: UserRole, avatar: String?) {
        self.id = id
        self.appleUserID = appleUserID
        self.name = name
        self.role = role
        self.avatar = avatar
        self.createdAt = nil
        self.updatedAt = nil
    }

    var toElder: Elder {
        Elder(id: id, name: name, avatar: avatar)
    }
}

private struct CaregiverAssignmentRow: Codable {
    var id: UUID?
    var childID: UUID
    var elderID: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case childID = "child_id"
        case elderID = "elder_id"
        case createdAt = "created_at"
    }

    init(childID: UUID, elderID: UUID) {
        self.id = nil
        self.childID = childID
        self.elderID = elderID
        self.createdAt = nil
    }
}

private struct SupabaseReminderRow: Codable {
    var id: UUID
    var elderID: UUID
    var createdBy: UUID
    var title: String
    var notes: String
    var date: Date
    var repeatOption: RepeatOption
    var earlyReminder: EarlyReminderOption
    var category: ReminderCategory
    var isCompleted: Bool
    var completedCount: Int
    var totalCount: Int
    var isPast: Bool
    var imageName: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case elderID = "elder_id"
        case createdBy = "created_by"
        case title
        case notes
        case date
        case repeatOption = "repeat_option"
        case earlyReminder = "early_reminder"
        case category
        case isCompleted = "is_completed"
        case completedCount = "completed_count"
        case totalCount = "total_count"
        case isPast = "is_past"
        case imageName = "image_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(model: Reminder, createdBy: UUID) {
        id = model.id
        elderID = model.elderID
        self.createdBy = createdBy
        title = model.title
        notes = model.notes
        date = model.date
        repeatOption = model.repeatOption
        earlyReminder = model.earlyReminder
        category = model.category
        isCompleted = model.isCompleted
        completedCount = model.completedCount
        totalCount = model.totalCount
        isPast = model.isPast
        imageName = model.imageName
        createdAt = nil
        updatedAt = nil
    }

    var toModel: Reminder {
        Reminder(
            id: id,
            title: title,
            notes: notes,
            date: date,
            repeatOption: repeatOption,
            earlyReminder: earlyReminder,
            category: category,
            isCompleted: isCompleted,
            completedCount: completedCount,
            totalCount: totalCount,
            elderID: elderID,
            isPast: isPast,
            imageName: imageName
        )
    }
}
