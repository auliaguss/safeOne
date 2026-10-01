//
//  SubscriptionManager.swift
//  safeOne
//

import Foundation
import Combine
import RevenueCat

/// Single source of premium state for the app.
/// Premium = an active RevenueCat "healder_pro" entitlement OR a locally redeemed code.
/// The local redeem path is temporary until the backend validates codes.
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    static let entitlementID = "healder_pro"

    /// Reusable promo codes — any account can redeem them.
    /// Move to the backend before release: anything in the binary can be extracted.
    private static let redeemCodes: Set<String> = ["SAFEONE2026"]

    @Published private(set) var isSubscribed = false
    /// Store packages from the current RevenueCat offering, once loaded.
    @Published private(set) var packages: [PremiumPlan: Package] = [:]

    private var userID: String?
    private var hasRedeemedCode = false
    private var hasActiveEntitlement = false

    private init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)

        // Picks up renewals/expirations that happen while the app is open.
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    private func storageKey(for userID: String) -> String {
        "is_subscribed_\(userID)"
    }

    private func apply(_ info: CustomerInfo) {
        hasActiveEntitlement = info.entitlements[Self.entitlementID]?.isActive == true
        isSubscribed = hasRedeemedCode || hasActiveEntitlement
    }

    /// Called by AppState whenever the signed-in account changes.
    func load(for userID: String?) {
        self.userID = userID
        hasActiveEntitlement = false
        hasRedeemedCode = userID.map { UserDefaults.standard.bool(forKey: storageKey(for: $0)) } ?? false
        isSubscribed = hasRedeemedCode

        Task {
            do {
                if let userID {
                    // Backend user id as appUserID, so purchases follow the account across devices.
                    let (info, _) = try await Purchases.shared.logIn(userID)
                    guard self.userID == userID else { return }
                    apply(info)
                } else if !Purchases.shared.isAnonymous {
                    _ = try await Purchases.shared.logOut()
                }
            } catch {
                print("❌ RevenueCat login failed: \(error.localizedDescription)")
            }
        }
    }

    /// Returns true when the code is valid and premium was unlocked for the current account.
    func redeem(_ code: String) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard Self.redeemCodes.contains(normalized), let userID else { return false }
        UserDefaults.standard.set(true, forKey: storageKey(for: userID))
        hasRedeemedCode = true
        isSubscribed = true
        return true
    }

    // MARK: - Store

    func loadOfferings() async {
        do {
            guard let offering = try await Purchases.shared.offerings().current else { return }
            var loaded: [PremiumPlan: Package] = [:]
            loaded[.monthly] = offering.monthly
            loaded[.yearly] = offering.annual
            packages = loaded
        } catch {
            print("❌ RevenueCat offerings failed: \(error.localizedDescription)")
        }
    }

    /// Returns true when the purchase unlocked premium, false when the user cancelled.
    /// Throws `SubscriptionError.planUnavailable` when the offering isn't set up.
    func purchase(_ plan: PremiumPlan) async throws -> Bool {
        if packages[plan] == nil { await loadOfferings() }
        guard let package = packages[plan] else { throw SubscriptionError.planUnavailable }

        let result = try await Purchases.shared.purchase(package: package)
        apply(result.customerInfo)
        return !result.userCancelled && isSubscribed
    }

    /// Returns true when a previous purchase was found and premium is active.
    func restore() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        apply(info)
        return isSubscribed
    }

    // MARK: - Display prices

    /// Store price when the offering is loaded, hardcoded fallback otherwise.
    func price(for plan: PremiumPlan) -> String {
        packages[plan]?.storeProduct.localizedPriceString ?? PremiumPlan.rupiah(plan.price)
    }

    /// Twelve months at the monthly price, shown struck through on the yearly card.
    func fullYearPrice() -> String? {
        guard let monthly = packages[.monthly]?.storeProduct,
              let yearly = packages[.yearly]?.storeProduct else {
            return PremiumPlan.yearly.fullPrice.map(PremiumPlan.rupiah)
        }
        return formatted(monthly.price * 12, like: yearly)
    }

    func yearlySavings() -> String? {
        guard let monthly = packages[.monthly]?.storeProduct,
              let yearly = packages[.yearly]?.storeProduct else {
            return PremiumPlan.yearly.savings.map(PremiumPlan.rupiah)
        }
        let savings = monthly.price * 12 - yearly.price
        return savings > 0 ? formatted(savings, like: yearly) : nil
    }

    private func formatted(_ amount: Decimal, like product: StoreProduct) -> String? {
        product.priceFormatter?.string(from: amount as NSDecimalNumber)
    }
}

enum SubscriptionError: Error {
    case planUnavailable
}

// MARK: - Plans

enum PremiumPlan: CaseIterable, Identifiable {
    case monthly, yearly

    var id: Self { self }

    // Fallback prices, shown until the RevenueCat offering loads.
    var price: Int {
        switch self {
        case .monthly: return 29_000
        case .yearly: return 299_000
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
