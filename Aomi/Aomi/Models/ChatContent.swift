import Foundation

enum ChatContent: Identifiable {
    case text(String)
    case toolUse(ToolUseCard)
    case toolResult(ToolResultCard)
    case widget(WidgetPayload)
    case error(String)

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
