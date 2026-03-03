import SwiftUI

struct WidgetRenderer: View {
    let payload: WidgetPayload

    var body: some View {
        switch payload.widgetType {
        case WidgetPayload.portfolioOverview:
            PortfolioOverviewWidget(data: payload.data)
        case WidgetPayload.tokenBalance:
            TokenBalanceWidget(data: payload.data)
        case WidgetPayload.priceChart:
            PriceChartWidget(data: payload.data)
        case WidgetPayload.defiPosition:
            DeFiPositionWidget(data: payload.data)
        case WidgetPayload.transactionConfirmation:
            TransactionConfirmationWidget(data: payload.data)
        default:
            // Unknown widget -- render raw JSON
            Text(payload.data.prettyString)
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
