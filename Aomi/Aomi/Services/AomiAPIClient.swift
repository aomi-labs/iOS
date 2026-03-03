import Foundation

@Observable
@MainActor
final class AomiAPIClient {
    let baseURL: String
    var sessionId: String?
    var publicKey: String?

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

    func renameSession(sessionId: String, title: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/sessions/\(sessionId)")!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        request.httpBody = try JSONEncoder().encode(["title": title])
        try await executeVoid(request)
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
