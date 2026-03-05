import Foundation

@Observable
@MainActor
final class AomiAPIClient {
    let baseURL: String
    var sessionId: String?
    var publicKey: String?
    var ensName: String?
    var pendingTransactions: [APIPendingTransaction] = []

    init(baseURL: String = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
    }

    // MARK: - Chat

    func sendMessage(_ message: String, namespace: String? = nil, userState: APIUserState? = nil) async throws -> SessionResponse {
        guard let sessionId else { throw APIError.noSession }
        let request = try buildChatRequest(
            sessionId: sessionId,
            message: message,
            namespace: namespace,
            publicKey: publicKey,
            userState: userState
        )
        return try await execute(request)
    }

    func getState(userState: APIUserState? = nil) async throws -> SessionResponse {
        guard let sessionId else { throw APIError.noSession }
        var components = URLComponents(string: "\(baseURL)/api/state")!
        var items: [URLQueryItem] = []
        if let userState, let json = try? JSONEncoder().encode(userState),
           let str = String(data: json, encoding: .utf8) {
            items.append(URLQueryItem(name: "user_state", value: str))
        }
        if !items.isEmpty { components.queryItems = items }
        var request = URLRequest(url: components.url!)
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        return try await execute(request)
    }

    func interrupt() async throws {
        guard let sessionId else { throw APIError.noSession }
        var request = URLRequest(url: URL(string: "\(baseURL)/api/interrupt")!)
        request.httpMethod = "POST"
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        let _: SessionResponse = try await execute(request)
    }

    // MARK: - Sessions

    func listSessions() async throws -> [APISessionItem] {
        guard let publicKey else { throw APIError.noPublicKey }
        let request = try buildSessionListRequest(publicKey: publicKey)
        return try await execute(request)
    }

    func createSession(sessionId: String) async throws -> APISessionItem {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/sessions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        var body: [String: String] = [:]
        if let publicKey { body["public_key"] = publicKey }
        request.httpBody = try JSONEncoder().encode(body)
        return try await execute(request)
    }

    func archiveSession(sessionId: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/sessions/\(sessionId)/archive")!)
        request.httpMethod = "POST"
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        try await executeVoid(request)
    }

    func deleteSession(sessionId: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/sessions/\(sessionId)")!)
        request.httpMethod = "DELETE"
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        try await executeVoid(request)
    }

    func unarchiveSession(sessionId: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/sessions/\(sessionId)/unarchive")!)
        request.httpMethod = "POST"
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        try await executeVoid(request)
    }

    func renameSession(sessionId: String, title: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/sessions/\(sessionId)")!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        request.httpBody = try JSONEncoder().encode(["title": title])
        try await executeVoid(request)
    }

    // MARK: - SSE Streaming

    func streamUpdates(userState: APIUserState? = nil) -> AsyncThrowingStream<SessionResponse, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let sessionId else { throw APIError.noSession }
                    var components = URLComponents(string: "\(baseURL)/api/updates")!
                    var items: [URLQueryItem] = []
                    if let userState, let json = try? JSONEncoder().encode(userState),
                       let str = String(data: json, encoding: .utf8) {
                        items.append(URLQueryItem(name: "user_state", value: str))
                    }
                    if !items.isEmpty { components.queryItems = items }
                    var request = URLRequest(url: components.url!)
                    request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 300

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
                    }

                    var dataLines: [String] = []
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if line.hasPrefix("data: ") {
                            dataLines.append(String(line.dropFirst(6)))
                        } else if line.isEmpty && !dataLines.isEmpty {
                            // End of SSE event — concatenate multi-line data
                            let combined = dataLines.joined(separator: "\n")
                            dataLines.removeAll()
                            if let data = combined.data(using: .utf8),
                               let response = try? JSONDecoder().decode(SessionResponse.self, from: data) {
                                continuation.yield(response)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - System

    func postSystemMessage(_ message: String) async throws {
        guard let sessionId else { throw APIError.noSession }
        var components = URLComponents(string: "\(baseURL)/api/system")!
        components.queryItems = [URLQueryItem(name: "message", value: message)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        try await executeVoid(request)
    }

    // MARK: - Control Plane

    func listModels() async throws -> [APIModelInfo] {
        guard let sessionId else { throw APIError.noSession }
        var request = URLRequest(url: URL(string: "\(baseURL)/api/control/models")!)
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        return try await execute(request)
    }

    func selectModel(rig: String, namespace: String? = nil) async throws {
        guard let sessionId else { throw APIError.noSession }
        var components = URLComponents(string: "\(baseURL)/api/control/model")!
        var items: [URLQueryItem] = [URLQueryItem(name: "rig", value: rig)]
        if let namespace { items.append(URLQueryItem(name: "namespace", value: namespace)) }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        try await executeVoid(request)
    }

    func listNamespaces() async throws -> [APINamespace] {
        guard let sessionId else { throw APIError.noSession }
        var request = URLRequest(url: URL(string: "\(baseURL)/api/control/namespaces")!)
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        return try await execute(request)
    }

    // MARK: - Events

    func getEvents(count: Int = 20) async throws -> [APIEvent] {
        var components = URLComponents(string: "\(baseURL)/api/events")!
        var items = [URLQueryItem(name: "count", value: String(count))]
        if let publicKey { items.append(URLQueryItem(name: "public_key", value: publicKey)) }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        if let sessionId { request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id") }
        return try await execute(request)
    }

    // MARK: - Wallet

    func bindWallet(address: String, platform: String, platformUserId: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/wallet/bind")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["wallet_address": address, "platform": platform, "platform_user_id": platformUserId]
        request.httpBody = try JSONEncoder().encode(body)
        try await executeVoid(request)
    }

    // MARK: - Request Builders (exposed for testing)

    func buildChatRequest(sessionId: String, message: String, namespace: String?, publicKey: String?, userState: APIUserState?) throws -> URLRequest {
        var components = URLComponents(string: "\(baseURL)/api/chat")!
        var items = [URLQueryItem(name: "message", value: message)]
        if let namespace { items.append(URLQueryItem(name: "namespace", value: namespace)) }
        if let publicKey { items.append(URLQueryItem(name: "public_key", value: publicKey)) }
        if let userState, let json = try? JSONEncoder().encode(userState),
           let str = String(data: json, encoding: .utf8) {
            items.append(URLQueryItem(name: "user_state", value: str))
        }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        return request
    }

    func buildSessionListRequest(publicKey: String) throws -> URLRequest {
        var components = URLComponents(string: "\(baseURL)/api/sessions")!
        components.queryItems = [URLQueryItem(name: "public_key", value: publicKey)]
        return URLRequest(url: components.url!)
    }

    // MARK: - Internal

    private func executeVoid(_ request: URLRequest) async throws {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    enum APIError: Error {
        case noSession
        case noPublicKey
        case invalidResponse
        case httpError(Int)
    }
}
