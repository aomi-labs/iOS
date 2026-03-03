import Foundation

struct WidgetPayload: Codable, Identifiable, Sendable {
    let id: String
    let widgetType: String
    let data: JSONValue

    enum CodingKeys: String, CodingKey {
        case widgetType = "widget_type"
        case data
    }

    init(id: String = UUID().uuidString, widgetType: String, data: JSONValue) {
        self.id = id
        self.widgetType = widgetType
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.widgetType = try container.decode(String.self, forKey: .widgetType)
        self.data = try container.decode(JSONValue.self, forKey: .data)
        self.id = UUID().uuidString
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(widgetType, forKey: .widgetType)
        try container.encode(data, forKey: .data)
    }
}

extension WidgetPayload {
    static let portfolioOverview = "portfolio_overview"
    static let tokenBalance = "token_balance"
    static let priceChart = "price_chart"
    static let defiPosition = "defi_position"
    static let transactionConfirmation = "transaction_confirmation"
}
