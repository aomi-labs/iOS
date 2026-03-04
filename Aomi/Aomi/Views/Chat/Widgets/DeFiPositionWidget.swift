import SwiftUI

struct DeFiPositionWidget: View {
    let data: JSONValue
    @State private var showDetail = false
    @State private var hasAppeared = false

    var body: some View {
        Button {
            HapticEngine.lightTap()
            showDetail = true
        } label: {
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
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.96)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.12)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showDetail) {
            DeFiPositionDetailSheet(data: data)
                .onAppear { HapticEngine.sheetPresented() }
        }
    }

    private var protocolName: String { data["protocol"]?.stringValue ?? "" }
    private var positionName: String { data["position_name"]?.stringValue ?? "" }
    private var currentValue: String { data["current_value"]?.stringValue ?? "$0.00" }
    private var pnl: String { data["pnl"]?.stringValue ?? "$0.00" }
    private var pnlIsPositive: Bool { !(pnl.hasPrefix("-")) }
}
