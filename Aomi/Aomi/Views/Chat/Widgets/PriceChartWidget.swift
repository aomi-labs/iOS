import Charts
import SwiftUI

struct PriceChartWidget: View {
    let data: JSONValue
    @State private var selectedPeriod = "1W"
    @State private var selectedIndex: Int?

    private let periods = ["1D", "1W", "1M", "1Y"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(symbol)
                    .font(.headline)
                Spacer()
                Text(selectedIndex.map { String(format: "$%.2f", chartData[$0]) } ?? currentPrice)
                    .font(.title3.bold())
            }

            Chart {
                ForEach(Array(chartData.enumerated()), id: \.offset) { i, point in
                    LineMark(
                        x: .value("Time", i),
                        y: .value("Price", point)
                    )
                    .foregroundStyle(Color.accentColor)
                    AreaMark(
                        x: .value("Time", i),
                        y: .value("Price", point)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.accentColor.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXSelection(value: $selectedIndex)
            .frame(height: 160)

            // Period selector
            HStack {
                ForEach(periods, id: \.self) { period in
                    Button(period) { selectedPeriod = period }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedPeriod == period ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(selectedPeriod == period ? .primary : .secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }

    private var symbol: String { data["symbol"]?.stringValue ?? "" }
    private var currentPrice: String { data["current_price"]?.stringValue ?? "$0.00" }
    private var chartData: [Double] {
        (data["chart_data"]?.arrayValue ?? []).compactMap(\.numberValue)
    }
}

struct PriceChartDetailSheet: View {
    let tokenSymbol: String
    let sparkline: [Double]

    var body: some View {
        NavigationStack {
            VStack {
                Chart {
                    ForEach(Array(sparkline.enumerated()), id: \.offset) { i, val in
                        LineMark(x: .value("", i), y: .value("", val))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: 200)
                .padding()
            }
            .navigationTitle(tokenSymbol)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
