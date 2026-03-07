import Foundation

enum ChatContent: Identifiable, Equatable {
    case text(String)
    case toolUse(ToolUseCard)
    case toolResult(ToolResultCard)
    case widget(WidgetPayload)
    case error(String)

    static func == (lhs: ChatContent, rhs: ChatContent) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): a == b
        case (.widget(let a), .widget(let b)): a == b
        case (.error(let a), .error(let b)): a == b
        case (.toolUse(let a), .toolUse(let b)): a === b
        case (.toolResult(let a), .toolResult(let b)): a === b
        default: false
        }
    }

    var id: String {
        switch self {
        case .text(let text): "text-\(text.prefix(50).hashValue)"
        case .toolUse(let card): "tool-\(card.toolUseId)"
        case .toolResult(let card): "result-\(card.toolUseId)"
        case .widget(let payload): "widget-\(payload.id)"
        case .error(let msg): "error-\(msg.hashValue)"
        }
    }
}
