import Foundation
import StoreKit
import Combine

enum PurchaseError: Error {
    case failedVerification
}

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: ProductIDCatalog.all)
            AppLog.info("[StoreKit] loaded products count=\(products.count)")
        } catch {
            AppLog.warning("[StoreKit] failed to load products: \(error.localizedDescription)")
        }
    }

    func loadProductsIfNeeded() async {
        if products.isEmpty {
            await loadProducts()
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()

        case .userCancelled:
            AppLog.info("[StoreKit] purchase cancelled")

        case .pending:
            AppLog.info("[StoreKit] purchase pending")

        @unknown default:
            AppLog.warning("[StoreKit] unknown purchase result")
        }
    }

    func refreshPurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if let transaction = try? checkVerified(result) {
                    purchasedProductIDs.insert(transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
