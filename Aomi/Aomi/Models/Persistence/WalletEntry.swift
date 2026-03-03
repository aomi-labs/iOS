import Foundation
import SwiftData

@Model
final class WalletEntry {
    var id: UUID
    var address: String
    var chain: String
    var label: String?
    var walletType: String
    var createdAt: Date

    init(address: String, chain: String, label: String? = nil, walletType: String) {
        self.id = UUID()
        self.address = address
        self.chain = chain
        self.label = label
        self.walletType = walletType
        self.createdAt = Date()
    }
}
