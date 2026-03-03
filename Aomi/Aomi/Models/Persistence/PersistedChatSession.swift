import Foundation
import SwiftData

@Model
final class PersistedChatSession {
    var id: UUID
    var title: String?
    var lastActiveAt: Date
    var createdAt: Date
    var messagesData: Data?
    var draftInputText: String?
    var isArchived: Bool
    var sessionId: String
    var publicKey: String?

    init(sessionId: String, publicKey: String? = nil) {
        self.id = UUID()
        self.sessionId = sessionId
        self.publicKey = publicKey
        self.lastActiveAt = Date()
        self.createdAt = Date()
        self.isArchived = false
    }
}
