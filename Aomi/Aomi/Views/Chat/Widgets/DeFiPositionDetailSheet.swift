import Charts
import SwiftUI

struct DeFiPositionDetailSheet: View {
    let data: JSONValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data["protocol"]?.stringValue ?? "")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(data["position_name"]?.stringValue ?? "")
                            .font(.title2.bold())
                    }

                    // Value chart
                    if !valueHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Value Over Time")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Chart {
                                ForEach(Array(valueHistory.enumerated()), id: \.offset) { i, val in
                                    LineMark(x: .value("", i), y: .value("", val))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 160)
                        }
                        .padding()
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Key metrics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metrics")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        metricRow("Current Value", data["current_value"]?.stringValue)
                        metricRow("Deposited", data["deposited_value"]?.stringValue)
                        metricRow("PnL", data["pnl"]?.stringValue)
                        metricRow("APY", data["apy"]?.stringValue)
                        metricRow("Health Factor", data["health_factor"]?.stringValue)
                        metricRow("Liquidation Price", data["liquidation_price"]?.stringValue)
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                    // Composition
                    if case .array(let tokens) = data["composition"] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Composition")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                                HStack {
                                    Text(token["symbol"]?.stringValue ?? "")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(token["amount"]?.stringValue ?? "")
                                        .font(.subheadline)
                                    Text(token["percentage"]?.stringValue ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Position Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    private var valueHistory: [Double] {
        (data["value_history"]?.arrayValue ?? []).compactMap(\.numberValue)
    }

    @ViewBuilder
    private func metricRow(_ label: String, _ value: String?) -> some View {
        if let value {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline.bold())
            }
        }
    }
}
