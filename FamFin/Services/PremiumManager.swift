import Foundation
import StoreKit

/// Manages the app's freemium model: a 6-month free trial, a one-time Pro
/// purchase, and a Premium monthly subscription that implies Pro access.
@MainActor @Observable
final class PremiumManager {

    // MARK: - Product identifiers

    static let proProductID = "com.famfin.app.pro"
    static let premiumMonthlyProductID = "com.famfin.app.premium.monthly"

    // MARK: - Entitlement model

    /// Ordered so that `Comparable` works naturally: free < pro < premium.
    enum Entitlement: Comparable {
        case free
        case pro
        case premium
    }

    // MARK: - Published state

    /// The highest entitlement the user currently holds.
    private(set) var entitlement: Entitlement = .free

    /// StoreKit `Product` objects fetched from the App Store.
    private(set) var proProduct: Product?
    private(set) var premiumProduct: Product?

    /// Whether a purchase or restore is in progress.
    private(set) var isPurchasing = false

    /// User-facing error message from the last failed operation.
    var purchaseError: String?

    // MARK: - Trial tracking

    /// The date the app was first launched. Persisted in UserDefaults.
    private(set) var installDate: Date

    /// Duration of the free trial.
    private static let trialDuration: TimeInterval = 6 * 30.44 * 24 * 60 * 60 // ~6 months

    private static let installDateKey = "com.famfin.installDate"

    // MARK: - Computed helpers

    /// `true` when the user has at least Pro-level access (Pro or Premium).
    var hasProAccess: Bool {
        entitlement >= .pro
    }

    /// `true` only when the user holds an active Premium subscription.
    var hasPremiumAccess: Bool {
        entitlement == .premium
    }

    /// `true` when the 6-month free trial period has not yet elapsed.
    var isTrialActive: Bool {
        Date.now < installDate.addingTimeInterval(Self.trialDuration)
    }

    /// Number of full days remaining in the trial. Returns 0 when expired.
    var trialDaysRemaining: Int {
        let end = installDate.addingTimeInterval(Self.trialDuration)
        let remaining = Calendar.current.dateComponents([.day], from: .now, to: end).day ?? 0
        return max(remaining, 0)
    }

    /// `true` when the trial has expired and the user has no purchase.
    var isTrialExpired: Bool {
        !isTrialActive && entitlement == .free
    }

    // MARK: - Private state

    /// Keeps the `Transaction.updates` listener alive for the app's lifetime.
    @ObservationIgnored
    private var updateListenerTask: Task<Void, Never>?

    // MARK: - Initialisation

    init() {
        // Resolve or record the install date.
        if let stored = UserDefaults.standard.object(forKey: Self.installDateKey) as? Date {
            installDate = stored
        } else {
            let now = Date.now
            UserDefaults.standard.set(now, forKey: Self.installDateKey)
            installDate = now
        }

        // Start listening for transaction updates (renewals, refunds, etc.).
        updateListenerTask = listenForTransactionUpdates()

        // Kick off the initial entitlement check.
        Task { await refreshEntitlements() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Products

    /// Fetches the `Product` objects from the App Store.
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [
                Self.proProductID,
                Self.premiumMonthlyProductID
            ])
            for product in products {
                switch product.id {
                case Self.proProductID:
                    proProduct = product
                case Self.premiumMonthlyProductID:
                    premiumProduct = product
                default:
                    break
                }
            }
        } catch {
            purchaseError = "Unable to load products. Please try again later."
        }
    }

    // MARK: - Purchases

    /// Purchase the one-time Pro unlock.
    func purchasePro() async {
        guard let product = proProduct else { return }
        await purchase(product)
    }

    /// Purchase the Premium monthly subscription.
    func purchasePremium() async {
        guard let product = premiumProduct else { return }
        await purchase(product)
    }

    /// Restore previous purchases by re-checking current entitlements.
    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = "Unable to restore purchases. Please try again."
        }
    }

    // MARK: - Private helpers

    /// Performs a StoreKit 2 purchase flow for the given product.
    private func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                // Transaction is waiting for approval (e.g. Ask to Buy).
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
        }
    }

    /// Iterates over current entitlements to determine the user's access level.
    func refreshEntitlements() async {
        var newEntitlement: Entitlement = .free

        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            switch transaction.productID {
            case Self.premiumMonthlyProductID:
                // An active subscription is the highest tier.
                newEntitlement = .premium
            case Self.proProductID:
                // Only upgrade if we haven't already found premium.
                if newEntitlement < .premium {
                    newEntitlement = .pro
                }
            default:
                break
            }
        }

        entitlement = newEntitlement
    }

    /// Listens for real-time transaction updates (renewals, revocations, etc.).
    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
    }

    /// Unwraps a `VerificationResult`, throwing if verification fails.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let value):
            return value
        }
    }

    // MARK: - Errors

    private enum StoreError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return "Transaction verification failed."
            }
        }
    }
}
