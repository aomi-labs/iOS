import SwiftUI

struct WalletPromptCard: View {
    var onCreateWallet: () -> Void
    var onAddWatch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wallet.bifold")
                    .foregroundStyle(.orange)
                Text("Wallet Required")
                    .font(.headline)
            }
            Text("To check balances and execute transactions, connect a wallet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Create Wallet") { onCreateWallet() }
                    .buttonStyle(.borderedProminent)
                Button("Add Address") { onAddWatch() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
