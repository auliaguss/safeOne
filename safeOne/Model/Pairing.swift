import Foundation

struct PairingRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var pairingCode: String
    var caregiverID: UUID
    var caregiverName: String
    var elderID: UUID?
    var elderName: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        pairingCode: String,
        caregiverID: UUID,
        caregiverName: String,
        elderID: UUID? = nil,
        elderName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pairingCode = pairingCode
        self.caregiverID = caregiverID
        self.caregiverName = caregiverName
        self.elderID = elderID
        self.elderName = elderName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

