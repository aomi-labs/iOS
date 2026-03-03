import Foundation
import SwiftData

@Observable
@MainActor
final class SessionListViewModel {
    var sessions: [SessionItem] = []
    var isLoading = false

    private let apiClient: AomiAPIClient

    init(apiClient: AomiAPIClient) {
        self.apiClient = apiClient
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let apiSessions = try await apiClient.listSessions()
            sessions = apiSessions.map { SessionItem(id: $0.sessionId, title: $0.title) }
        } catch {
            // On failure, keep existing sessions
        }
    }

    func createNewSession() -> String {
        let sessionId = UUID().uuidString
        sessions.insert(SessionItem(id: sessionId, title: nil), at: 0)
        return sessionId
    }

    func archiveSession(id: String) async {
        sessions.removeAll { $0.id == id }
        try? await apiClient.archiveSession(sessionId: id)
    }
}

struct SessionItem: Identifiable {
    let id: String
    var title: String?

    var displayTitle: String {
        title ?? "New Conversation"
    }
}
