import Foundation
import StoreKit
import Combine

/// Producto de propina. Son consumibles: se pueden comprar muchas veces y
/// no desbloquean nada. Toda la app es gratis y sigue siéndolo tras donar —
/// eso es justamente lo que la guía 3.2.2 de App Review espera de un modelo
/// "supported by donations".
struct TipProduct: Identifiable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let emoji: String

    static let identifiers = [
        "com.carlyrics.tip.small",
        "com.carlyrics.tip.medium",
        "com.carlyrics.tip.large"
    ]

    static func emoji(for id: String) -> String {
        switch id {
        case "com.carlyrics.tip.small": return "☕️"
        case "com.carlyrics.tip.medium": return "🍕"
        case "com.carlyrics.tip.large": return "🚀"
        default: return "💚"
        }
    }
}

enum TipJarState: Equatable {
    case idle
    case loading
    case ready([TipProduct])
    case unavailable(String)
}

/// Tip jar con StoreKit 2.
///
/// Nota importante para App Review: las donaciones a un desarrollador deben
/// pasar por compra in-app (no se puede linkear a PayPal/Ko-fi). La excepción
/// de pago externo aplica sólo a organizaciones sin fines de lucro
/// registradas. Ver docs/DONATIONS.md.
@MainActor
final class TipJar: ObservableObject {
    @Published private(set) var state: TipJarState = .idle
    @Published private(set) var isPurchasing = false
    @Published var lastThankYou: String?

    private let settings: UserSettings
    private var updatesTask: Task<Void, Never>?

    init(settings: UserSettings = .shared) {
        self.settings = settings
        listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    func load() async {
        if case .ready = state { return }
        state = .loading
        await fetchProducts()
    }

    func purchase(_ tip: TipProduct) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let products = try await Product.products(for: [tip.id])
            guard let product = products.first else {
                state = .unavailable(L10n.tipsUnavailable)
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                // Un consumible hay que terminarlo siempre, aunque no
                // desbloquee nada: si no, StoreKit lo vuelve a entregar.
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    settings.hasEverTipped = true
                    lastThankYou = L10n.tipsThankYou
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            Log.store.error("Compra falló: \(error.localizedDescription, privacy: .public)")
            state = .unavailable(error.localizedDescription)
        }
    }

    // MARK: - Interno

    private func fetchProducts() async {
        do {
            let products = try await Product.products(for: TipProduct.identifiers)
            guard !products.isEmpty else {
                state = .unavailable(L10n.tipsUnavailable)
                return
            }

            let tips = products
                .sorted { $0.price < $1.price }
                .map {
                    TipProduct(
                        id: $0.id,
                        displayName: $0.displayName,
                        displayPrice: $0.displayPrice,
                        emoji: TipProduct.emoji(for: $0.id)
                    )
                }
            state = .ready(tips)
        } catch {
            Log.store.error("No se pudieron cargar los productos: \(error.localizedDescription, privacy: .public)")
            state = .unavailable(L10n.tipsUnavailable)
        }
    }

    /// StoreKit puede entregar transacciones fuera del flujo de compra
    /// (compras hechas en otro dispositivo, o interrumpidas). Hay que
    /// escucharlas y terminarlas, o quedan pendientes para siempre.
    private func listenForTransactions() {
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await MainActor.run { self?.settings.hasEverTipped = true }
            }
        }
    }
}
