//
//  SubscriptionManager.swift
//  safeOne
//

import Foundation
import Combine
import RevenueCat

/// Single source of premium state for the app.
/// RevenueCat handles the App Store transaction. The backend is the source of
/// truth for the user's Pro access and expiry date.
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    static let entitlementID = "healder_pro"

    @Published private(set) var isSubscribed = false
    @Published private(set) var expiredPro: Date?
    @Published private(set) var proPlan: PremiumPlan?
    /// Store packages from the current RevenueCat offering, once loaded.
    @Published private(set) var packages: [PremiumPlan: Package] = [:]

    private var userID: String?
    private var authToken: String?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
            }
            return date
        }
        return decoder
    }()

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

    private func apply(_ info: CustomerInfo) {
        // RevenueCat state does not replace the backend account status.
        _ = info
    }

    /// Called by AppState whenever the signed-in account changes.
    func load(for userID: String?, token: String?) {
        self.userID = userID
        self.authToken = token
        expiredPro = nil
        proPlan = nil
        isSubscribed = false

        Task {
            if let userID {
                do {
                    // Backend user id as appUserID, so purchases follow the account across devices.
                    let (info, _) = try await Purchases.shared.logIn(userID)
                    guard self.userID == userID else { return }
                    apply(info)
                } catch {
                    print("❌ RevenueCat login failed: \(error.localizedDescription)")
                }
                guard self.userID == userID else { return }
                _ = await refreshStatus()
            } else if !Purchases.shared.isAnonymous {
                do {
                    _ = try await Purchases.shared.logOut()
                } catch {
                    print("❌ RevenueCat logout failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Refreshes Pro state from the authenticated backend account.
    @discardableResult
    func refreshStatus() async -> Bool {
        guard userID != nil, let authToken,
              let url = URL(string: "\(AppConfig.baseURL)/subscriptions/pro") else { return false }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            let status = try decoder.decode(SubscriptionStatus.self, from: data)
            guard self.authToken == authToken else { return false }
            apply(status)
            return isSubscribed
        } catch {
            print("❌ Subscription status failed: \(error.localizedDescription)")
            return false
        }
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
        guard !result.userCancelled else { return false }
        try await activateOnBackend(plan: plan)
        return await refreshStatus()
    }

    /// Returns true when a previous purchase was found and premium is active.
    func restore() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        apply(info)
        return await refreshStatus()
    }

    private func activateOnBackend(plan: PremiumPlan) async throws {
        guard userID != nil, let authToken,
              let url = URL(string: "\(AppConfig.baseURL)/subscriptions/pro") else {
            throw SubscriptionError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["plan": plan.rawValue])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        apply(try decoder.decode(SubscriptionStatus.self, from: data))
    }

    private func apply(_ status: SubscriptionStatus) {
        expiredPro = status.expiredPro
        proPlan = status.plan.flatMap(PremiumPlan.init(rawValue:))
        isSubscribed = status.isPro && (status.expiredPro ?? .distantPast) > Date()
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(BackendError.self, from: data))?.error
            throw SubscriptionError.backend(message ?? "Subscription request failed")
        }
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

enum SubscriptionError: Error, LocalizedError {
    case planUnavailable
    case notAuthenticated
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .planUnavailable: return "Subscription plan is not available."
        case .notAuthenticated: return "Please sign in before subscribing."
        case .backend(let message): return message
        }
    }
}

// MARK: - Plans

enum PremiumPlan: String, CaseIterable, Identifiable {
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

private struct SubscriptionStatus: Decodable {
    let isPro: Bool
    let expiredPro: Date?
    let plan: String?

    enum CodingKeys: String, CodingKey {
        case isPro
        case expiredPro = "expired_pro"
        case plan
    }
}

private struct BackendError: Decodable {
    let error: String
}
