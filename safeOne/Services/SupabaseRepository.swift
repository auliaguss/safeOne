import Foundation
import Auth
import PostgREST
import Supabase
import UIKit

final class SupabaseRepository {
    static let shared = SupabaseRepository()

    private let client = SupabaseManager.shared.client

    var isAvailable: Bool {
        client.auth.currentSession != nil
    }

    func loadProfile(roleFallback: UserRole = .children) async throws -> UserProfile {
        let userID = try currentUserID()
        let rows: [SupabaseUserRow] = try await client.database
            .from("users")
            .select()
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        if let row = rows.first {
            return row.toModel(connectedDevices: [currentDevice(role: row.role)])
        }

        return try await createCurrentUserPlaceholder(role: roleFallback)
    }

    func upsertProfile(_ profile: UserProfile) async throws -> UserProfile {
        let row = SupabaseUserRow(model: profile, authUserID: try currentUserID())
        let rows: [SupabaseUserRow] = try await client.database
            .from("users")
            .upsert(row, onConflict: "id")
            .select()
            .execute()
            .value

        return rows.first?.toModel(connectedDevices: profile.connectedDevices)
            ?? profile
    }

    func loadConnectedDevices() async throws -> [ConnectedDevice] {
        let profile = try await loadProfile()
        return profile.connectedDevices
    }

    func loadElders() async throws -> [Elder] {
        let userID = try currentUserID()
        let assignmentRows: [CaregiverAssignmentRow] = try await client.database
            .from("caregiver_assignments")
            .select()
            .eq("child_id", value: userID.uuidString)
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

    func loadPairings() async throws -> [PairingRecord] {
        let userID = try currentUserID()
        let rows: [SupabasePairingRow] = try await client.database
            .from("pairings")
            .select()
            .or("caregiver_id.eq.\(userID.uuidString),elder_id.eq.\(userID.uuidString)")
            .execute()
            .value

        return rows.map(\.toModel)
    }

    func generatePairingCode() async throws -> PairingRecord {
        let caregiverID = try currentUserID()
        let caregiverProfile = try await loadProfile()
        let code = Self.makePairingCode()
        let row = SupabasePairingRow(
            pairingCode: code,
            caregiverID: caregiverID,
            caregiverName: caregiverProfile.name,
            elderID: nil,
            elderName: nil
        )

        let rows: [SupabasePairingRow] = try await client.database
            .from("pairings")
            .upsert(row, onConflict: "caregiver_id")
            .select()
            .execute()
            .value

        if let first = rows.first {
            return first.toModel
        }

        return row.toModel
    }

    func joinPairing(code: String) async throws -> PairingRecord {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let elderID = try currentUserID()
        let elderProfile = try await loadProfile()
        let pairingRows: [SupabasePairingRow] = try await client.database
            .from("pairings")
            .select()
            .eq("pairing_code", value: normalized)
            .limit(1)
            .execute()
            .value

        guard let pairing = pairingRows.first else {
            throw SupabaseRepositoryError.missingPairingCode
        }

        let updatedRow = SupabasePairingRow(
            pairingCode: normalized,
            caregiverID: pairing.caregiverID,
            caregiverName: pairing.caregiverName,
            elderID: elderID,
            elderName: elderProfile.name
        )

        _ = try await client.database
            .from("pairings")
            .upsert(updatedRow, onConflict: "pairing_code")
            .select()
            .execute()

        let assignment = CaregiverAssignmentRow(childID: pairing.caregiverID, elderID: elderID)
        _ = try await client.database
            .from("caregiver_assignments")
            .upsert(assignment, onConflict: "child_id,elder_id")
            .execute()

        return updatedRow.toModel
    }

    func createElder(name: String) async throws -> Elder {
        let caregiverID = try currentUserID()
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

    func removeElderAssignments(ids: [UUID]) async throws {
        let caregiverID = try currentUserID()
        for elderID in ids {
            _ = try await client.database
                .from("caregiver_assignments")
                .delete()
                .eq("child_id", value: caregiverID.uuidString)
                .eq("elder_id", value: elderID.uuidString)
                .execute()
        }
    }

    func loadReminders(userID: UUID? = nil) async throws -> [Reminder] {
        var query = client.database
            .from("reminders")
            .select()

        if let userID {
            query = query.eq("elder_id", value: userID.uuidString)
        } else {
            let currentUserID = try currentUserID()
            query = query.eq("elder_id", value: currentUserID.uuidString)
        }

        let rows: [SupabaseReminderRow] = try await query.execute().value
        return rows.map(\.toModel)
    }

    func upsertReminder(_ reminder: Reminder) async throws -> Reminder {
        let currentUserID = try currentUserID()
        let row = SupabaseReminderRow(model: reminder, createdBy: currentUserID)

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

    private func currentUserID() throws -> UUID {
        guard let rawValue = client.auth.currentSession?.user.id,
              let userID = UUID(uuidString: String(describing: rawValue))
        else {
            throw SupabaseRepositoryError.missingSession
        }

        return userID
    }

    private func createCurrentUserPlaceholder(role: UserRole) async throws -> UserProfile {
        let userID = try currentUserID()
        let fallback = UserProfile(
            id: userID,
            name: "SafeOne User",
            email: nil,
            role: role,
            avatar: nil,
            connectedDevices: [currentDevice(role: role)],
            notificationPreferences: NotificationPreferences(
                sound: .default,
                hapticsEnabled: true,
                textToSpeechEnabled: true
            )
        )

        let rows: [SupabaseUserRow] = try await client.database
            .from("users")
            .upsert(SupabaseUserRow(model: fallback, authUserID: userID), onConflict: "id")
            .select()
            .execute()
            .value

        return rows.first?.toModel(connectedDevices: fallback.connectedDevices) ?? fallback
    }

    private func currentDevice(role: UserRole) -> ConnectedDevice {
        ConnectedDevice(
            id: UUID(),
            name: UIDevice.current.name,
            role: role,
            isCurrentDevice: true,
            lastSeenAt: Date()
        )
    }
}

enum SupabaseRepositoryError: LocalizedError {
    case missingSession
    case missingPairingCode

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Supabase session is missing."
        case .missingPairingCode:
            return "Pairing code was not found."
        }
    }
}

private extension SupabaseRepository {
    static func makePairingCode(length: Int = 6) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var code = ""
        while code.count < length {
            let index = Int.random(in: 0..<alphabet.count)
            code.append(alphabet[index])
        }
        return code
    }
}

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

    init(
        id: UUID,
        appleUserID: String?,
        name: String,
        role: UserRole,
        avatar: String?
    ) {
        self.id = id
        self.appleUserID = appleUserID
        self.name = name
        self.role = role
        self.avatar = avatar
        self.createdAt = nil
        self.updatedAt = nil
    }

    init(model: UserProfile, authUserID: UUID) {
        id = model.id
        appleUserID = authUserID.uuidString
        name = model.name
        role = model.role
        avatar = model.avatar
        createdAt = nil
        updatedAt = nil
    }

    func toModel(connectedDevices: [ConnectedDevice]) -> UserProfile {
        UserProfile(
            id: id,
            name: name,
            email: nil,
            role: role,
            avatar: avatar,
            connectedDevices: connectedDevices,
            notificationPreferences: NotificationPreferences(
                sound: .default,
                hapticsEnabled: true,
                textToSpeechEnabled: true
            )
        )
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

private struct SupabasePairingRow: Codable {
    var id: UUID?
    var pairingCode: String
    var caregiverID: UUID
    var caregiverName: String
    var elderID: UUID?
    var elderName: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case pairingCode = "pairing_code"
        case caregiverID = "caregiver_id"
        case caregiverName = "caregiver_name"
        case elderID = "elder_id"
        case elderName = "elder_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var toModel: PairingRecord {
        PairingRecord(
            id: id ?? UUID(),
            pairingCode: pairingCode,
            caregiverID: caregiverID,
            caregiverName: caregiverName,
            elderID: elderID,
            elderName: elderName,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
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
