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
            let profile = row.toModel(connectedDevices: [currentDevice(role: row.role)])
            if row.isMissingName {
                return try await upsertProfile(profile)
            }
            return profile
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

    func loadConnectedDevices(roleFallback: UserRole = .children) async throws -> [ConnectedDevice] {
        let profile = try await loadProfile(roleFallback: roleFallback)
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
        let rows: [ElderOTPCodeRow] = try await client.database
            .from("elder_otp_codes")
            .select()
            .or("elder_id.eq.\(userID.uuidString),used_by.eq.\(userID.uuidString)")
            .execute()
            .value

        var pairings: [PairingRecord] = []
        for row in rows {
            let caregiver: SupabaseUserRow?
            if let usedBy = row.usedBy {
                caregiver = try await loadUser(usedBy)
            } else {
                caregiver = nil
            }
            let elder: SupabaseUserRow?
            elder = try await loadUser(row.elderID)
            pairings.append(row.toPairing(caregiver: caregiver, elder: elder))
        }

        return pairings
    }

    func generatePairingCode() async throws -> PairingRecord {
        let elderID = try currentUserID()
        let elderProfile = try await loadProfile()
        let code = Self.makePairingCode()
        let row = ElderOTPCodeRow(
            elderID: elderID,
            code: code,
            expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )

        let rows: [ElderOTPCodeRow] = try await client.database
            .from("elder_otp_codes")
            .insert(row)
            .select()
            .execute()
            .value

        if let first = rows.first {
            return first.toPairing(caregiver: nil, elder: SupabaseUserRow(model: elderProfile, authUserID: elderID))
        }

        return row.toPairing(caregiver: nil, elder: SupabaseUserRow(model: elderProfile, authUserID: elderID))
    }

    func joinPairing(code: String) async throws -> PairingRecord {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let caregiverID = try currentUserID()
        let caregiverProfile = try await loadProfile()
        let pairingRows: [ElderOTPCodeRow] = try await client.database
            .from("elder_otp_codes")
            .select()
            .eq("code", value: normalized)
            .limit(1)
            .execute()
            .value

        guard let codeRow = pairingRows.first else {
            throw SupabaseRepositoryError.missingPairingCode
        }

        guard codeRow.elderID != caregiverID else {
            throw SupabaseRepositoryError.selfPairing
        }

        if let usedBy = codeRow.usedBy, usedBy != caregiverID {
            throw SupabaseRepositoryError.pairingCodeAlreadyUsed
        }

        try await insertCaregiverAssignmentIfNeeded(childID: caregiverID, elderID: codeRow.elderID)

        let updatedRow: ElderOTPCodeRow
        if codeRow.usedBy == caregiverID {
            updatedRow = codeRow
        } else {
            let update = ElderOTPCodeUpdate(usedAt: Date(), usedBy: caregiverID)
            let updatedRows: [ElderOTPCodeRow] = try await client.database
                .from("elder_otp_codes")
                .update(update)
                .eq("id", value: codeRow.id.uuidString)
                .select()
                .execute()
                .value
            updatedRow = updatedRows.first ?? codeRow
        }

        let elder = try await loadUser(codeRow.elderID)
        return updatedRow
            .toPairing(caregiver: SupabaseUserRow(model: caregiverProfile, authUserID: caregiverID), elder: elder)
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

    private func loadUser(_ id: UUID) async throws -> SupabaseUserRow? {
        let rows: [SupabaseUserRow] = try await client.database
            .from("users")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    private func insertCaregiverAssignmentIfNeeded(childID: UUID, elderID: UUID) async throws {
        let existingRows: [CaregiverAssignmentRow] = try await client.database
            .from("caregiver_assignments")
            .select()
            .eq("child_id", value: childID.uuidString)
            .eq("elder_id", value: elderID.uuidString)
            .limit(1)
            .execute()
            .value

        guard existingRows.isEmpty else { return }

        let assignment = CaregiverAssignmentRow(childID: childID, elderID: elderID)
        _ = try await client.database
            .from("caregiver_assignments")
            .insert(assignment)
            .execute()
    }

    private func createCurrentUserPlaceholder(role: UserRole) async throws -> UserProfile {
        let userID = try currentUserID()
        let fallback = UserProfile(
            id: userID,
            name: Self.defaultName(for: role),
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
    case selfPairing
    case pairingCodeAlreadyUsed

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Supabase session is missing."
        case .missingPairingCode:
            return "Pairing code was not found."
        case .selfPairing:
            return "Use a different Apple account for the caregiver. An elder cannot pair with the same account."
        case .pairingCodeAlreadyUsed:
            return "This pairing code was already used by another caregiver. Generate a new code on the elder device."
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

    static func defaultName(for role: UserRole) -> String {
        switch role {
        case .elder:
            return "Elder"
        case .children:
            return "Caregiver"
        }
    }
}

private struct SupabaseUserRow: Codable {
    var id: UUID
    var appleUserID: String?
    var name: String?
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
            name: normalizedName,
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
        Elder(id: id, name: normalizedName, avatar: avatar)
    }

    private var normalizedName: String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty {
            return trimmedName
        }

        return SupabaseRepository.defaultName(for: role)
    }

    var isMissingName: Bool {
        name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
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

private struct ElderOTPCodeRow: Codable {
    var id: UUID
    var elderID: UUID
    var code: String
    var expiresAt: Date
    var usedAt: Date?
    var usedBy: UUID?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case elderID = "elder_id"
        case code
        case expiresAt = "expires_at"
        case usedAt = "used_at"
        case usedBy = "used_by"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        elderID: UUID,
        code: String,
        expiresAt: Date,
        usedAt: Date? = nil,
        usedBy: UUID? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.elderID = elderID
        self.code = code
        self.expiresAt = expiresAt
        self.usedAt = usedAt
        self.usedBy = usedBy
        self.createdAt = createdAt
    }

    func toPairing(caregiver: SupabaseUserRow?, elder: SupabaseUserRow?) -> PairingRecord {
        PairingRecord(
            id: id,
            pairingCode: code,
            caregiverID: usedBy ?? id,
            caregiverName: caregiver?.name ?? "SafeOne User",
            elderID: elderID,
            elderName: elder?.name,
            createdAt: createdAt ?? Date(),
            updatedAt: usedAt ?? createdAt ?? Date()
        )
    }
}

private struct ElderOTPCodeUpdate: Codable {
    var usedAt: Date
    var usedBy: UUID

    enum CodingKeys: String, CodingKey {
        case usedAt = "used_at"
        case usedBy = "used_by"
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
