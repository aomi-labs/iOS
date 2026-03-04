import SwiftUI

struct TransactionConfirmationWidget: View {
    let data: JSONValue
    @Environment(ParaWalletService.self) private var walletService
    @State private var isSigning = false
    @State private var result: TransactionResult?
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.up.right.circle")
                    .foregroundStyle(.orange)
                Text("Transaction Request")
                    .font(.headline)
            }

            // Details
            VStack(alignment: .leading, spacing: 6) {
                detailRow("Action", description)
                detailRow("From", truncate(from))
                detailRow("To", truncate(to))
                detailRow("Value", value)
                detailRow("Gas (est)", gas)
                detailRow("Chain", chain)
            }
            .font(.subheadline)

            // Actions
            if let result {
                Label(
                    result == .signed ? "Signed" : "Rejected",
                    systemImage: result == .signed ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(result == .signed ? .green : .red)
                .font(.subheadline.bold())
                .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 12) {
                    Button {
                        HapticEngine.transactionRejected()
                        withAnimation(.spring(duration: 0.3)) {
                            result = .rejected
                        }
                    } label: {
                        Text("Reject")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        HapticEngine.mediumTap()
                        signTransaction()
                    } label: {
                        if isSigning {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSigning)
                }
            }
        }
        .padding()
        .glassEffect(.regular.tint(.orange.opacity(0.15)), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
        )
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.96)
        .onAppear {
            HapticEngine.warning()
            withAnimation(.spring(duration: 0.4, bounce: 0.12)) {
                hasAppeared = true
            }
        }
        .animation(.spring(duration: 0.3), value: result != nil)
    }

    private func signTransaction() {
        guard let walletId = walletService.wallets.first(where: { $0.type == .evm })?.id,
              let message = data["sign_data"]?.stringValue else { return }
        isSigning = true
        Task {
            do {
                _ = try await walletService.signMessage(walletId: walletId, message: message)
                HapticEngine.transactionSigned()
                withAnimation(.spring(duration: 0.3)) {
                    result = .signed
                }
            } catch {
                HapticEngine.error()
                withAnimation(.spring(duration: 0.3)) {
                    result = .rejected
                }
            }
            isSigning = false
        }
    }

    private var description: String { data["description"]?.stringValue ?? "" }
    private var from: String { data["from"]?.stringValue ?? "" }
    private var to: String { data["to"]?.stringValue ?? "" }
    private var value: String { data["value"]?.stringValue ?? "0" }
    private var gas: String { data["gas"]?.stringValue ?? "" }
    private var chain: String { data["chain"]?.stringValue ?? "" }

    private func truncate(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    enum TransactionResult {
        case signed, rejected
    }
}
