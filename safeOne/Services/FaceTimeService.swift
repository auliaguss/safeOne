import Foundation
import UIKit

struct FaceTimeContact: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var address: String
    var isPrimary: Bool

    init(id: UUID = UUID(), name: String, address: String, isPrimary: Bool = false) {
        self.id = id
        self.name = name
        self.address = address
        self.isPrimary = isPrimary
    }
}

final class FaceTimeService {
    static let shared = FaceTimeService()

    private init() {}

    func facetimeURL(for address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized: String
        if trimmed.contains("@") {
            normalized = trimmed
        } else {
            let allowed = CharacterSet(charactersIn: "+0123456789")
            normalized = String(trimmed.filter { String($0).rangeOfCharacter(from: allowed) != nil })
        }
        let escaped = normalized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? normalized
        return URL(string: "facetime://\(escaped)")
    }

    @MainActor
    func open(address: String) {
        guard let url = facetimeURL(for: address) else { return }
        UIApplication.shared.open(url)
    }
}
