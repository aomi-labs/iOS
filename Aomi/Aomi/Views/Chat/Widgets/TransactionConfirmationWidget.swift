import BigInt
import ParaSwift
import SwiftUI

struct TransactionConfirmationWidget: View {
    let data: JSONValue
    @Environment(ParaWalletService.self) private var walletService
    @Environment(AomiAPIClient.self) private var apiClient
    @State private var isSigning = false
    @State private var result: TransactionResult?
    @State private var txHash: String?
    @State private var statusMessage: String?
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

            // Result state
            if let result {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        result.label,
                        systemImage: result.icon
                    )
                    .foregroundStyle(result.color)
                    .font(.subheadline.bold())

                    if let txHash {
                        Text(truncate(txHash))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                HStack(spacing: 12) {
                    Button {
                        rejectTransaction()
                    } label: {
                        Text("Reject")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        HapticEngine.mediumTap()
                        signAndBroadcast()
                    } label: {
                        if isSigning {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign & Send")
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

    private func rejectTransaction() {
        HapticEngine.transactionRejected()
        withAnimation(.spring(duration: 0.3)) {
            result = .rejected
        }
        reportResult(txHash: nil, status: "rejected")
    }

    private func signAndBroadcast() {
        guard let walletId = walletService.wallets.first(where: { $0.type == .evm })?.id else { return }

        let txTo = data["to"]?.stringValue
        let txValue = parseBigUInt(data["value"]?.stringValue)
        let txData = data["data"]?.stringValue
        let txChainId = data["chain_id"]?.stringValue ?? "1"
        let chainIdInt = Int(txChainId) ?? 1
        let fromAddress = data["from"]?.stringValue ?? walletService.primaryAddress

        isSigning = true
        statusMessage = "Estimating gas..."

        Task {
            do {
                let rpcURL = ChainConfig.rpcURL(for: chainIdInt)

                // Step 0: Estimate gas from the RPC node
                let gasHex = try await EthereumRPC.estimateGas(
                    to: txTo,
                    from: fromAddress,
                    value: data["value"]?.stringValue,
                    data: txData,
                    rpcURL: rpcURL
                )
                // Add 20% buffer to estimate
                let estimatedGas = parseHexUInt64(gasHex)
                let bufferedGas = BigUInt(estimatedGas) * 120 / 100

                let transaction = EVMTransaction(
                    to: txTo,
                    value: txValue ?? BigUInt(0),
                    gasLimit: bufferedGas,
                    smartContractByteCode: txData,
                    type: 2
                )

                // Step 1: Sign via Para SDK
                statusMessage = "Signing..."
                let signedTx = try await walletService.signTransaction(
                    walletId: walletId,
                    transaction: transaction,
                    chainId: txChainId
                )

                // Step 2: Broadcast via RPC
                statusMessage = "Broadcasting..."
                let hash = try await EthereumRPC.sendRawTransaction(signedTx: signedTx, rpcURL: rpcURL)

                txHash = hash
                HapticEngine.transactionSigned()
                withAnimation(.spring(duration: 0.3)) {
                    result = .broadcast
                }

                // Step 3: Report success to backend
                reportResult(txHash: hash, status: "success")

            } catch {
                HapticEngine.error()
                statusMessage = error.localizedDescription
                withAnimation(.spring(duration: 0.3)) {
                    result = .failed
                }
                reportResult(txHash: nil, status: "failed")
            }
            isSigning = false
        }
    }

    private func reportResult(txHash: String?, status: String) {
        let payload: [String: Any] = [
            "type": "wallet:tx_complete",
            "payload": [
                "txHash": txHash ?? "",
                "status": status
            ]
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        Task {
            try? await apiClient.postSystemMessage(jsonString)
            NotificationCenter.default.post(name: .transactionCompleted, object: nil)
        }
    }

    private func parseHexUInt64(_ hex: String) -> UInt64 {
        let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        return UInt64(stripped, radix: 16) ?? 21000
    }

    private func parseBigUInt(_ string: String?) -> BigUInt? {
        guard let string, !string.isEmpty else { return nil }
        if string.hasPrefix("0x") {
            return BigUInt(String(string.dropFirst(2)), radix: 16)
        }
        return BigUInt(string)
    }

    private var description: String { data["description"]?.stringValue ?? "" }
    private var from: String { data["from"]?.stringValue ?? walletService.primaryAddress ?? "" }
    private var to: String { data["to"]?.stringValue ?? "" }
    private var value: String { data["value"]?.stringValue ?? "0" }
    private var gas: String { data["gas"]?.stringValue ?? "Estimated at signing" }
    private var chain: String { data["chain"]?.stringValue ?? data["chain_name"]?.stringValue ?? "ethereum" }

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
        case broadcast, rejected, failed

        var label: String {
            switch self {
            case .broadcast: "Broadcast"
            case .rejected: "Rejected"
            case .failed: "Failed"
            }
        }

        var icon: String {
            switch self {
            case .broadcast: "checkmark.circle.fill"
            case .rejected: "xmark.circle.fill"
            case .failed: "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .broadcast: .green
            case .rejected: .red
            case .failed: .red
            }
        }
    }
}

extension Notification.Name {
    static let transactionCompleted = Notification.Name("transactionCompleted")
}
