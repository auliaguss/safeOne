//
//  SubscriptionManager.swift
//  safeOne
//

import Foundation
import Combine

/// Local-only premium state, stored per account in UserDefaults.
/// Temporary until RevenueCat + the backend become the source of truth.
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// Reusable promo codes — any account can redeem them.
    /// Move to the backend before release: anything in the binary can be extracted.
    private static let redeemCodes: Set<String> = ["SAFEONE2026"]

    @Published private(set) var isSubscribed = false
    private var userID: String?

    private init() {}

    private func storageKey(for userID: String) -> String {
        "is_subscribed_\(userID)"
    }

    /// Called by AppState whenever the signed-in account changes.
    func load(for userID: String?) {
        self.userID = userID
        guard let userID else {
            isSubscribed = false
            return
        }
        isSubscribed = UserDefaults.standard.bool(forKey: storageKey(for: userID))
    }

    /// Returns true when the code is valid and premium was unlocked for the current account.
    func redeem(_ code: String) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard Self.redeemCodes.contains(normalized), let userID else { return false }
        UserDefaults.standard.set(true, forKey: storageKey(for: userID))
        isSubscribed = true
        return true
    }
}

// MARK: - Plans

enum PremiumPlan: CaseIterable, Identifiable {
    case monthly, yearly

    var id: Self { self }

    // Hardcoded until prices come from RevenueCat offerings.
    var price: Int {
        switch self {
        case .monthly: return 29_999
        case .yearly: return 299_999
        }
    }

    /// Yearly price if paid monthly, shown struck through.
    var fullPrice: Int? {
        self == .yearly ? PremiumPlan.monthly.price * 12 : nil
    }

    var savings: Int? {
        fullPrice.map { $0 - price }
    }

    static func rupiah(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.usesGroupingSeparator = true
        return "Rp" + (formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }
}
