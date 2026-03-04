import SwiftUI

struct WalletRowView: View {
    let address: String
    let chain: String
    let label: String?
    let badge: String
    @State private var showCopied = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let label {
                    Text(label)
                        .font(.subheadline.bold())
                }
                HStack(spacing: 6) {
                    Text(truncatedAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button {
                        UIPasteboard.general.string = address
                        HapticEngine.lightTap()
                        showCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            showCopied = false
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: showCopied)
                }
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
                    .glassEffect(
                        badge == "signing"
                            ? .regular.tint(.green.opacity(0.3))
                            : .regular,
                        in: Capsule()
                    )
                    .foregroundStyle(badge == "signing" ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Copy Address", systemImage: "doc.on.doc") {
                HapticEngine.lightTap()
                UIPasteboard.general.string = address
            }
        }
    }

    private var truncatedAddress: String {
        guard address.count > 14 else { return address }
        return "\(address.prefix(8))...\(address.suffix(6))"
    }
}
