import Foundation

@Observable
@MainActor
final class ToolUseCard: Identifiable {
    let id: String
    let toolUseId: String
    let toolName: String
    let input: JSONValue
    let startedAt: Date
    var result: ToolResultCard?

    init(toolUseId: String, toolName: String, input: JSONValue, startedAt: Date = Date()) {
        self.id = toolUseId
        self.toolUseId = toolUseId
        self.toolName = toolName
        self.input = input
        self.startedAt = startedAt
    }

    var summary: String {
        switch toolName {
        case "cast_balance": "Checking balance..."
        case "cast_call": "Calling contract..."
        case "cast_send": "Sending transaction..."
        case "etherscan_abi": "Fetching ABI..."
        case "brave_search": input["query"]?.stringValue ?? "Searching..."
        case "zerox_quote": "Getting swap quote..."
        default: toolName
        }
    }

    var iconName: String {
        switch toolName {
        case "cast_balance", "cast_call": "chart.bar"
        case "cast_send": "arrow.up.right"
        case "etherscan_abi": "doc.text"
        case "brave_search": "magnifyingglass"
        case "zerox_quote": "arrow.triangle.swap"
        default: "wrench"
        }
    }

    var elapsedString: String? {
        guard let completedAt = result?.completedAt else { return nil }
        let elapsed = completedAt.timeIntervalSince(startedAt)
        if elapsed < 1 { return "<1s" }
        else if elapsed < 60 { return "\(Int(elapsed))s" }
        else { return "\(Int(elapsed) / 60)m \(Int(elapsed) % 60)s" }
    }
}

@Observable
@MainActor
final class ToolResultCard: Identifiable {
    let id: String
    let toolUseId: String
    let toolName: String
    let content: JSONValue
    let completedAt: Date

    init(toolUseId: String, toolName: String, content: JSONValue, completedAt: Date = Date()) {
        self.id = toolUseId
        self.toolUseId = toolUseId
        self.toolName = toolName
        self.content = content
        self.completedAt = completedAt
    }

    var displayContent: String {
        switch content {
        case .string(let text): text
        case .array(let items):
            items.compactMap(\.stringValue).joined(separator: "\n")
        default: content.prettyString
        }
    }
}
