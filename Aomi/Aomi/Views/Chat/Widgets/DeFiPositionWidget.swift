import SwiftUI

struct DeFiPositionWidget: View {
    let data: JSONValue
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(protocolName)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(positionName)
                        .font(.subheadline.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currentValue)
                        .font(.subheadline.bold())
                    Text(pnl)
                        .font(.caption)
                        .foregroundStyle(pnlIsPositive ? .green : .red)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            DeFiPositionDetailSheet(data: data)
        }
    }

    private var protocolName: String { data["protocol"]?.stringValue ?? "" }
    private var positionName: String { data["position_name"]?.stringValue ?? "" }
    private var currentValue: String { data["current_value"]?.stringValue ?? "$0.00" }
    private var pnl: String { data["pnl"]?.stringValue ?? "$0.00" }
    private var pnlIsPositive: Bool { !(pnl.hasPrefix("-")) }
}
