import Foundation
import SwiftData
import ParaSwift

@Observable
@MainActor
final class WalletViewModel {
    var watchAddresses: [WalletEntry] = []
    var isLoading = false
    var errorMessage = ""

    private let walletService: ParaWalletService

    init(walletService: ParaWalletService) {
        self.walletService = walletService
    }

    var paraWallets: [ParaWalletInfo] {
        walletService.wallets.compactMap { wallet in
            guard let address = wallet.address else { return nil }
            let chain: String = {
                switch wallet.type {
                case .evm: return "EVM"
                case .solana: return "Solana"
                case .cosmos: return "Cosmos"
                case .none: return "Unknown"
                }
            }()
            return ParaWalletInfo(id: wallet.id, address: address, chain: chain)
        }
    }

    func loadWallets() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await walletService.fetchWallets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadWatchAddresses(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<WalletEntry>(
            predicate: #Predicate { $0.walletType == "watch" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        watchAddresses = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addWatchAddress(_ address: String, chain: String, label: String?, modelContext: ModelContext) {
        let entry = WalletEntry(address: address, chain: chain, label: label, walletType: "watch")
        modelContext.insert(entry)
        loadWatchAddresses(modelContext: modelContext)
    }

    func removeWatchAddress(_ entry: WalletEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
        loadWatchAddresses(modelContext: modelContext)
    }

    static func cacheParaWallets(_ wallets: [Wallet], modelContext: ModelContext) {
        // Delete existing para entries
        let descriptor = FetchDescriptor<WalletEntry>(
            predicate: #Predicate { $0.walletType == "para" }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for entry in existing {
                modelContext.delete(entry)
            }
        }
        // Insert current Para wallets
        for wallet in wallets {
            guard let address = wallet.address else { continue }
            let chain: String = {
                switch wallet.type {
                case .evm: return "EVM"
                case .solana: return "Solana"
                case .cosmos: return "Cosmos"
                case .none: return "Unknown"
                }
            }()
            let entry = WalletEntry(address: address, chain: chain, label: nil, walletType: "para")
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }

    static func cachedParaAddresses(modelContext: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<WalletEntry>(
            predicate: #Predicate { $0.walletType == "para" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor))?.map(\.address) ?? []
    }
}

struct ParaWalletInfo: Identifiable {
    let id: String
    let address: String
    let chain: String
}
