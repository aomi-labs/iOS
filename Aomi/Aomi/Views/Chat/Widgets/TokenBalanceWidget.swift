import Charts
import SwiftUI

struct TokenBalanceWidget: View {
    let data: JSONValue

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(symbol)
                    .font(.headline)
                Text(balance)
                    .font(.title3.bold())
                Text(usdValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !sparkline.isEmpty {
                Chart {
                    ForEach(Array(sparkline.enumerated()), id: \.offset) { i, val in
                        LineMark(x: .value("", i), y: .value("", val))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 80, height: 40)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }

    private var symbol: String { data["symbol"]?.stringValue ?? "" }
    private var balance: String { data["balance"]?.stringValue ?? "0" }
    private var usdValue: String { data["usd_value"]?.stringValue ?? "$0.00" }
    private var sparkline: [Double] {
        (data["sparkline"]?.arrayValue ?? []).compactMap(\.numberValue)
    }
}
