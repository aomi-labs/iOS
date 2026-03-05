import Foundation
import SwiftData

@Observable
@MainActor
final class SessionListViewModel {
    var sessions: [SessionItem] = []
    var archivedSessions: [SessionItem] = []
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
            sessions = apiSessions
                .filter { !$0.isArchived }
                .map { SessionItem(id: $0.sessionId, title: $0.title) }
            archivedSessions = apiSessions
                .filter { $0.isArchived }
                .map { SessionItem(id: $0.sessionId, title: $0.title) }
        } catch {
            // On failure, keep existing sessions
        }
    }

    func createNewSession() -> String {
        let sessionId = UUID().uuidString
        sessions.insert(SessionItem(id: sessionId, title: nil), at: 0)
        return sessionId
    }

    func updateSessionTitle(id: String, title: String) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].title = title
        }
    }

    func archiveSession(id: String) async {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            let session = sessions.remove(at: index)
            archivedSessions.insert(session, at: 0)
        }
        try? await apiClient.archiveSession(sessionId: id)
    }

    func deleteSession(id: String) async {
        sessions.removeAll { $0.id == id }
        archivedSessions.removeAll { $0.id == id }
        try? await apiClient.deleteSession(sessionId: id)
    }

    func unarchiveSession(id: String) async {
        if let index = archivedSessions.firstIndex(where: { $0.id == id }) {
            let session = archivedSessions.remove(at: index)
            sessions.insert(session, at: 0)
        }
        try? await apiClient.unarchiveSession(sessionId: id)
    }
}

struct SessionItem: Identifiable {
    let id: String
    var title: String?

    var displayTitle: String {
        title ?? "New Conversation"
    }
}
