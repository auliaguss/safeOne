import Foundation

struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var user: UserProfile
}

struct UserProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var email: String?
    var role: UserRole
    var avatar: String?
    var connectedDevices: [ConnectedDevice]
    var notificationPreferences: NotificationPreferences
}

struct ConnectedDevice: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var role: UserRole
    var isCurrentDevice: Bool
    var lastSeenAt: Date?
}

struct EmergencyContact: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var phoneNumber: String
    var category: EmergencyContactCategory
    var isPrimary: Bool

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String,
        category: EmergencyContactCategory,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.category = category
        self.isPrimary = isPrimary
    }
}

enum EmergencyContactCategory: String, Codable, CaseIterable {
    case caregiver = "Caregiver"
    case ambulance = "Ambulance"
    case hospital = "Hospital"
    case police = "Police"
    case firefighters = "Firefighters"
    case family = "Family"
    case other = "Other"
}

struct NotificationPreferences: Codable, Equatable {
    var sound: AlertSound
    var hapticsEnabled: Bool
    var textToSpeechEnabled: Bool
}

enum AlertSound: String, Codable, CaseIterable {
    case none = "None"
    case `default` = "Default"
    case gentle = "Gentle"
    case urgent = "Urgent"
}
