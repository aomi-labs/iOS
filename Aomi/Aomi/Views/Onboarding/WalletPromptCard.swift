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
                Button("Create Wallet") {
                    HapticEngine.buttonTap()
                    onCreateWallet()
                }
                .buttonStyle(.borderedProminent)
                Button("Add Address") {
                    HapticEngine.buttonTap()
                    onAddWatch()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .glassEffect(.regular.tint(.orange.opacity(0.1)), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
        )
    }
}
