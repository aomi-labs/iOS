import Foundation

enum ChatRole: String, Sendable, Codable {
    case user
    case assistant
    case system
}

@Observable
@MainActor
final class ChatMessage: Identifiable {
    nonisolated let id: UUID
    let timestamp: Date
    let role: ChatRole
    var content: [ChatContent]

    init(id: UUID = UUID(), timestamp: Date = Date(), role: ChatRole, content: [ChatContent] = []) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.content = content
    }

    var textContent: String {
        content.compactMap {
            if case .text(let text) = $0 { return text }
            return nil
        }.joined(separator: "\n\n")
    }
}
