import SwiftUI

struct WalletRowView: View {
    let address: String
    let chain: String
    let label: String?
    let badge: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let label {
                    Text(label)
                        .font(.subheadline.bold())
                }
                Text(truncatedAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(chain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(badge)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        badge == "signing" ? Color.green.opacity(0.15) : Color.gray.opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(badge == "signing" ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Copy Address", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = address
            }
        }
    }

    private var truncatedAddress: String {
        guard address.count > 14 else { return address }
        return "\(address.prefix(8))...\(address.suffix(6))"
    }
}
