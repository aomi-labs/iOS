import Charts
import SwiftUI

struct PortfolioOverviewWidget: View {
    let data: JSONValue
    @State private var selectedToken: String?
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Portfolio")
                    .font(.headline)
                Spacer()
                Text(totalValue)
                    .font(.title2.bold())
            }

            // Token list
            ForEach(tokens, id: \.symbol) { token in
                Button {
                    HapticEngine.lightTap()
                    selectedToken = token.symbol
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(Color(.systemGray4))
                            .frame(width: 24, height: 24)

                        Text(token.symbol)
                            .font(.subheadline.bold())
                            .frame(width: 50, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text(token.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !token.sparkline.isEmpty {
                            Chart {
                                ForEach(Array(token.sparkline.enumerated()), id: \.offset) { i, val in
                                    LineMark(x: .value("", i), y: .value("", val))
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(width: 50, height: 24)
                        }
                        VStack(alignment: .trailing) {
                            Text(token.balance)
                                .font(.subheadline)
                            Text(token.usdValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.96)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.12)) {
                hasAppeared = true
            }
        }
        .sheet(item: $selectedToken) { symbol in
            if let token = tokens.first(where: { $0.symbol == symbol }) {
                PriceChartDetailSheet(tokenSymbol: token.symbol, sparkline: token.sparkline)
                    .onAppear { HapticEngine.sheetPresented() }
            }
        }
    }

    private var totalValue: String {
        data["total_value"]?.stringValue ?? "$0.00"
    }

    private var tokens: [TokenRow] {
        guard case .array(let items) = data["tokens"] else { return [] }
        return items.compactMap { item in
            guard let symbol = item["symbol"]?.stringValue,
                  let name = item["name"]?.stringValue,
                  let balance = item["balance"]?.stringValue,
                  let usdValue = item["usd_value"]?.stringValue else { return nil }
            let sparkline: [Double] = (item["sparkline"]?.arrayValue ?? []).compactMap(\.numberValue)
            return TokenRow(symbol: symbol, name: name, balance: balance, usdValue: usdValue, sparkline: sparkline)
        }
    }
}

private struct TokenRow {
    let symbol: String
    let name: String
    let balance: String
    let usdValue: String
    let sparkline: [Double]
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
