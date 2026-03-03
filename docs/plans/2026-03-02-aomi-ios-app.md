# Aomi iOS App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native iOS app for aomi -- a conversational AI blockchain assistant with embedded Para wallet and rich inline widgets for portfolio, charts, and DeFi positions.

**Architecture:** SwiftUI MVVM with `@Observable` ViewModels. SwiftData for local persistence. URLSession for REST + polling against aomi's existing Rust/Axum backend. Para SDK for embedded wallet (create, sign). Rich widgets rendered as native SwiftUI views inline in chat.

**Tech Stack:** iOS 17+, SwiftUI, Swift Charts, SwiftData, ParaSwift 2.6.0, MarkdownUI

**Reference codebases:**
- Aomi backend: `/Users/zakimanian/code/aomi/product-mono`
- Wisp (chat UI patterns): `/Users/zakimanian/code/wisp`
- Alpha AI (Para wallet patterns): `/Users/zakimanian/code/alpha_ai/alpha_ai_mobile`

---

## Task 1: Xcode Project Scaffold

**Goal:** Create the Xcode project with correct structure, dependencies, and a "Hello World" that builds.

**Files:**
- Create: `Aomi/project.yml` (XcodeGen spec)
- Create: `Aomi/Aomi/App/AomiApp.swift`
- Create: `Aomi/Aomi/App/AppConfig.swift`
- Create: `Aomi/AomiTests/AomiTests.swift`

**Step 1: Install xcodegen if needed**

```bash
which xcodegen || brew install xcodegen
```

**Step 2: Create project.yml**

```yaml
name: Aomi
options:
  bundleIdPrefix: io.aomi
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    DEVELOPMENT_TEAM: ""

packages:
  ParaSwift:
    url: https://github.com/getpara/swift-sdk
    exactVersion: "2.6.0"
  MarkdownUI:
    url: https://github.com/gonzalezreal/swift-markdown-ui
    from: "2.4.0"

targets:
  Aomi:
    type: application
    platform: iOS
    sources:
      - path: Aomi
    settings:
      base:
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: true
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: true
        INFOPLIST_KEY_UILaunchScreen_Generation: true
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait"
    dependencies:
      - package: ParaSwift
      - package: MarkdownUI
    info:
      path: Aomi/Info.plist
      properties:
        CFBundleURLTypes:
          - CFBundleURLSchemes: ["aomi"]
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false

  AomiTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: AomiTests
    dependencies:
      - target: Aomi
```

**Step 3: Create directory structure**

```bash
mkdir -p Aomi/Aomi/{App,Views/{Onboarding,SessionList,Chat/Widgets,Wallet},ViewModels,Models/Persistence,Services,Utilities}
mkdir -p Aomi/AomiTests
```

**Step 4: Create AomiApp.swift**

```swift
import SwiftData
import SwiftUI

@main
struct AomiApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Aomi")
        }
        .modelContainer(for: [PersistedChatSession.self, WalletEntry.self])
    }
}
```

**Step 5: Create placeholder SwiftData models so it compiles**

Create `Aomi/Aomi/Models/Persistence/PersistedChatSession.swift`:
```swift
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
```

Create `Aomi/Aomi/Models/Persistence/WalletEntry.swift`:
```swift
import Foundation
import SwiftData

@Model
final class WalletEntry {
    var id: UUID
    var address: String
    var chain: String
    var label: String?
    var walletType: String // "para" or "watch"
    var createdAt: Date

    init(address: String, chain: String, label: String? = nil, walletType: String) {
        self.id = UUID()
        self.address = address
        self.chain = chain
        self.label = label
        self.walletType = walletType
        self.createdAt = Date()
    }
}
```

**Step 6: Create AppConfig.swift**

```swift
import Foundation

enum AppConfig {
    #if DEBUG
    // Use "localhost" for simulator, or your machine's local IP (e.g., "192.168.1.5") for physical devices.
    static let apiBaseURL = "http://localhost:8080"
    #else
    static let apiBaseURL = "https://api.aomi.io"
    #endif

    static let paraEnvironment = "beta" // "beta" or "prod"
    static let paraAppScheme = "aomi"
    
    // Suggestion: Use a CDN for token icons
    static func tokenIconURL(symbol: String) -> URL? {
        URL(string: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/\(symbol)/logo.png")
    }
}
```

**Step 7: Create placeholder test**

```swift
import XCTest
@testable import Aomi

final class AomiTests: XCTestCase {
    func testAppLaunches() {
        XCTAssertTrue(true)
    }
}
```

**Step 8: Generate Xcode project and verify build**

```bash
cd Aomi && xcodegen generate
xcodebuild -project Aomi.xcodeproj -scheme Aomi -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 9: Commit**

```bash
git add Aomi/
git commit -m "feat: scaffold Aomi iOS project with dependencies"
```

---

## Task 2: Core Data Models

**Goal:** Define all runtime models for chat messages, content blocks, widget payloads, and API types. These are the in-memory types used during a session (distinct from SwiftData persistence models).

**Files:**
- Create: `Aomi/Aomi/Models/ChatMessage.swift`
- Create: `Aomi/Aomi/Models/ChatContent.swift`
- Create: `Aomi/Aomi/Models/WidgetPayload.swift`
- Create: `Aomi/Aomi/Models/ToolUseCard.swift`
- Create: `Aomi/Aomi/Models/APITypes.swift`
- Create: `Aomi/Aomi/Utilities/JSONValue.swift`
- Test: `Aomi/AomiTests/ModelsTests.swift`

**Step 1: Write model tests**

```swift
import XCTest
@testable import Aomi

final class ModelsTests: XCTestCase {
    func testChatMessageCreation() {
        let msg = ChatMessage(role: .user, content: [.text("Hello")])
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.textContent, "Hello")
    }

    func testWidgetPayloadDecoding() throws {
        let json = """
        {"widget_type":"portfolio_overview","data":{"total_value":"12345.67","tokens":[]}}
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(WidgetPayload.self, from: json)
        XCTAssertEqual(payload.widgetType, "portfolio_overview")
    }

    func testSessionResponseDecoding() throws {
        let json = """
        {
          "messages": [
            {"sender":"user","content":"hello","timestamp":"12:00:00 UTC","is_streaming":false}
          ],
          "system_events": [],
          "title": "Test",
          "is_processing": false
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SessionResponse.self, from: json)
        XCTAssertEqual(response.messages.count, 1)
        XCTAssertEqual(response.messages[0].sender, .user)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Aomi.xcodeproj -scheme AomiTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test|error"
```

Expected: FAIL -- types don't exist yet

**Step 3: Create JSONValue.swift**

Adapted from Wisp's `JSONValue.swift` -- a flexible JSON enum for arbitrary tool inputs/outputs:

```swift
import Foundation

enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let dict) = self { return dict[key] }
        return nil
    }

    var prettyString: String {
        guard let data = try? JSONEncoder().encode(self),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
              let str = String(data: pretty, encoding: .utf8) else {
            return String(describing: self)
        }
        return str
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else if let n = try? container.decode(Double.self) { self = .number(n) }
        else if let s = try? container.decode(String.self) { self = .string(s) }
        else if let a = try? container.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? container.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}
```

**Step 4: Create ChatMessage.swift**

```swift
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
```

**Step 5: Create ChatContent.swift**

```swift
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
```

**Step 6: Create ToolUseCard.swift**

```swift
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
```

**Step 7: Create WidgetPayload.swift**

```swift
import Foundation

struct WidgetPayload: Codable, Identifiable {
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
}

// Known widget types
extension WidgetPayload {
    static let portfolioOverview = "portfolio_overview"
    static let tokenBalance = "token_balance"
    static let priceChart = "price_chart"
    static let defiPosition = "defi_position"
    static let transactionConfirmation = "transaction_confirmation"
}
```

**Step 8: Create APITypes.swift**

Maps to aomi backend's Rust types:

```swift
import Foundation

// Maps to Rust SessionResponse
struct SessionResponse: Codable {
    let messages: [APIMessage]
    let systemEvents: [JSONValue]
    let title: String?
    let isProcessing: Bool
    let userState: APIUserState?

    enum CodingKeys: String, CodingKey {
        case messages
        case systemEvents = "system_events"
        case title
        case isProcessing = "is_processing"
        case userState = "user_state"
    }
}

// Maps to Rust ChatMessage
struct APIMessage: Codable {
    let sender: MessageSender
    let content: String
    let toolResult: ToolResultTuple?
    let timestamp: String
    let isStreaming: Bool

    enum CodingKeys: String, CodingKey {
        case sender, content, timestamp
        case toolResult = "tool_result"
        case isStreaming = "is_streaming"
    }

    enum MessageSender: String, Codable {
        case user
        case agent
        case system
    }
}

// tool_result is serialized as a 2-element array [topic, content]
struct ToolResultTuple: Codable {
    let topic: String
    let content: String

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.topic = try container.decode(String.self)
        self.content = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(topic)
        try container.encode(content)
    }
}

// Maps to Rust UserState
struct APIUserState: Codable {
    let address: String?
    let chainId: UInt64?
    let isConnected: Bool
    let ensName: String?
    let pendingTransactions: [APIPendingTransaction]

    enum CodingKeys: String, CodingKey {
        case address
        case chainId = "chain_id"
        case isConnected = "is_connected"
        case ensName = "ens_name"
        case pendingTransactions = "pending_transactions"
    }

    init(address: String? = nil, chainId: UInt64? = nil, isConnected: Bool = false, ensName: String? = nil, pendingTransactions: [APIPendingTransaction] = []) {
        self.address = address
        self.chainId = chainId
        self.isConnected = isConnected
        self.ensName = ensName
        self.pendingTransactions = pendingTransactions
    }
}

// Maps to Rust PendingTransaction
struct APIPendingTransaction: Codable, Identifiable {
    let id: String
    let chainId: UInt64
    let from: String
    let to: String
    let value: String
    let data: String
    let gas: String
    let description: String
    let createdAt: Int64
    let state: String

    enum CodingKeys: String, CodingKey {
        case id
        case chainId = "chain_id"
        case from, to, value, data, gas, description
        case createdAt = "created_at"
        case state
    }
}

// Session list item
struct APISessionItem: Codable, Identifiable {
    let sessionId: String
    let title: String?
    let isArchived: Bool

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case title
        case isArchived = "is_archived"
    }
}
```

**Step 9: Run tests**

```bash
xcodebuild test -project Aomi.xcodeproj -scheme AomiTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test|PASS|FAIL"
```

Expected: All 3 tests PASS

**Step 10: Commit**

```bash
git add Aomi/
git commit -m "feat: add core data models and API types"
```

---

## Task 3: API Client & Keychain Service

**Goal:** Build the networking layer that talks to aomi's backend, plus secure token storage.

**Files:**
- Create: `Aomi/Aomi/Services/AomiAPIClient.swift`
- Create: `Aomi/Aomi/Services/KeychainService.swift`
- Test: `Aomi/AomiTests/APIClientTests.swift`

**Step 1: Write API client tests**

```swift
import XCTest
@testable import Aomi

final class APIClientTests: XCTestCase {
    func testBuildChatRequest() throws {
        let client = AomiAPIClient(baseURL: "https://api.test.com")
        let request = try client.buildChatRequest(
            sessionId: "test-session",
            message: "hello",
            namespace: nil,
            publicKey: "0x123",
            userState: nil
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Session-Id"), "test-session")
        XCTAssertTrue(request.url!.absoluteString.contains("message=hello"))
    }

    func testBuildSessionListRequest() throws {
        let client = AomiAPIClient(baseURL: "https://api.test.com")
        let request = try client.buildSessionListRequest(publicKey: "0x123")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url!.absoluteString.contains("public_key=0x123"))
    }
}
```

**Step 2: Run tests to verify failure**

**Step 3: Create KeychainService.swift**

```swift
import Foundation
import Security

enum KeychainService {
    private static let service = "io.aomi.app"

    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error {
        case saveFailed(OSStatus)
    }
}
```

**Step 4: Create AomiAPIClient.swift**

```swift
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
        let _ = try await URLSession.shared.data(for: request)
    }

    func renameSession(sessionId: String, title: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/sessions/\(sessionId)")!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        request.httpBody = try JSONEncoder().encode(["title": title])
        let _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Wallet

    func bindWallet(address: String, platform: String, platformUserId: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/api/wallet/bind")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["wallet_address": address, "platform": platform, "platform_user_id": platformUserId]
        request.httpBody = try JSONEncoder().encode(body)
        let _ = try await URLSession.shared.data(for: request)
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

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding Error for \(T.self): \(error)")
            throw APIError.decodingError(error)
        }
    }

    enum APIError: Error {
        case noSession
        case noPublicKey
        case invalidResponse
        case httpError(Int)
        case decodingError(Error)
    }
}
```

**Step 5: Run tests**

Expected: All tests PASS

**Step 6: Commit**

```bash
git add Aomi/
git commit -m "feat: add API client and keychain service"
```

---

## Task 4: Para Wallet Service & Auth ViewModel

**Goal:** Wrap Para SDK in a service layer. Build the auth view model that handles login, wallet creation, and watch address management.

**Files:**
- Create: `Aomi/Aomi/Services/ParaWalletService.swift`
- Create: `Aomi/Aomi/ViewModels/AuthViewModel.swift`
- Create: `Aomi/Aomi/ViewModels/WalletViewModel.swift`

**Step 1: Create ParaWalletService.swift**

```swift
import Foundation
import ParaSwift

@Observable
@MainActor
final class ParaWalletService {
    let paraManager: ParaManager
    private(set) var isLoggedIn = false
    private(set) var wallets: [Wallet] = []
    private(set) var email: String?

    init(environment: ParaEnvironment = .beta, apiKey: String, appScheme: String) {
        self.paraManager = ParaManager(
            environment: environment,
            apiKey: apiKey,
            appScheme: appScheme
        )
    }

    // MARK: - Auth

    func checkAuthStatus() async {
        do {
            isLoggedIn = try await paraManager.isFullyLoggedIn()
            if isLoggedIn {
                email = try await paraManager.getEmail()
            }
        } catch {
            isLoggedIn = false
        }
    }

    func initiateAuth(input: String) async throws -> AuthState {
        let auth: Auth = input.contains("@") ? .email(input) : .phone(input)
        return try await paraManager.initiateAuthFlow(auth: auth)
    }

    func handleVerification(code: String) async throws -> AuthState {
        try await paraManager.handleVerificationCode(verificationCode: code)
    }

    func handleSignup(authState: AuthState, authorizationController: AuthorizationController) async throws {
        #if targetEnvironment(simulator)
        try await paraManager.handleSignup(
            authState: authState,
            method: .password,
            authorizationController: authorizationController
        )
        #else
        try await paraManager.handleSignup(
            authState: authState,
            method: .passkey,
            authorizationController: authorizationController
        )
        #endif
    }

    func handleLogin(authState: AuthState, authorizationController: AuthorizationController) async throws {
        #if targetEnvironment(simulator)
        if paraManager.isLoginMethodAvailable(method: .password, authState: authState) {
            try await paraManager.handleLoginWithMethod(
                authState: authState,
                method: .password,
                authorizationController: authorizationController
            )
        }
        #else
        try await paraManager.handleLogin(
            authState: authState,
            authorizationController: authorizationController
        )
        #endif
    }

    // MARK: - Wallets

    func fetchWallets() async throws {
        wallets = try await paraManager.fetchWallets()
    }

    func createWallet(type: WalletType) async throws {
        try await paraManager.createWallet(type: type, skipDistributable: false)
        try await fetchWallets()
    }

    func signMessage(walletId: String, message: String) async throws -> String {
        try await paraManager.signMessage(walletId: walletId, message: message)
    }

    /// Get the primary EVM wallet address (for use as public_key in aomi API)
    var primaryAddress: String? {
        wallets.first(where: { $0.type == .evm })?.address
    }

    // MARK: - Logout

    func logout() {
        isLoggedIn = false
        email = nil
        wallets = []
    }
}
```

**Step 2: Create AuthViewModel.swift**

```swift
import SwiftUI
import ParaSwift
import AuthenticationServices

@Observable
@MainActor
final class AuthViewModel {
    var errorMessage = ""
    var isLoading = false
    var needsOTPVerification = false
    var authState: AuthState?

    private let walletService: ParaWalletService

    init(walletService: ParaWalletService) {
        self.walletService = walletService
    }

    func initiateLogin(input: String) async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            let state = try await walletService.initiateAuth(input: input)
            switch state.stage {
            case .login, .done:
                authState = state
                // Will complete in handleLogin call from view
            case .verify, .signup:
                authState = state
                needsOTPVerification = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyOTP(code: String) async -> Bool {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            let verifiedState = try await walletService.handleVerification(code: code)
            authState = verifiedState
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func completeAuth(authorizationController: AuthorizationController) async -> Bool {
        guard let authState else { return false }
        isLoading = true
        defer { isLoading = false }

        do {
            switch authState.stage {
            case .signup:
                try await walletService.handleSignup(
                    authState: authState,
                    authorizationController: authorizationController
                )
            case .login:
                try await walletService.handleLogin(
                    authState: authState,
                    authorizationController: authorizationController
                )
            case .done:
                break
            case .verify:
                errorMessage = "Unexpected state"
                return false
            }

            // Post-auth: create EVM wallet if none exists
            try await walletService.fetchWallets()
            if walletService.wallets.isEmpty {
                try await walletService.createWallet(type: .evm)
            }
            await walletService.checkAuthStatus()
            return walletService.isLoggedIn
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
```

**Step 3: Create WalletViewModel.swift**

```swift
import Foundation
import SwiftData

@Observable
@MainActor
final class WalletViewModel {
    var watchAddresses: [WalletEntry] = []
    var isLoading = false
    var errorMessage = ""

    private let walletService: ParaWalletService

    init(walletService: ParaWalletService) {
        self.walletService = walletService
    }

    var paraWallets: [ParaWalletInfo] {
        walletService.wallets.compactMap { wallet in
            guard let address = wallet.address else { return nil }
            return ParaWalletInfo(
                id: wallet.id,
                address: address,
                chain: wallet.type == .evm ? "EVM" : wallet.type == .solana ? "Solana" : "Other"
            )
        }
    }

    func loadWallets() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await walletService.fetchWallets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadWatchAddresses(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<WalletEntry>(
            predicate: #Predicate { $0.walletType == "watch" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        watchAddresses = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addWatchAddress(_ address: String, chain: String, label: String?, modelContext: ModelContext) {
        let entry = WalletEntry(address: address, chain: chain, label: label, walletType: "watch")
        modelContext.insert(entry)
        loadWatchAddresses(modelContext: modelContext)
    }

    func removeWatchAddress(_ entry: WalletEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
        loadWatchAddresses(modelContext: modelContext)
    }
}

struct ParaWalletInfo: Identifiable {
    let id: String
    let address: String
    let chain: String
}
```

**Step 4: Verify build**

```bash
xcodebuild -project Aomi.xcodeproj -scheme Aomi -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

**Step 5: Commit**

```bash
git add Aomi/
git commit -m "feat: add Para wallet service and auth/wallet view models"
```

---

## Task 5: Session List

**Goal:** Build the home screen -- list of conversations with create/archive.

**Files:**
- Create: `Aomi/Aomi/ViewModels/SessionListViewModel.swift`
- Create: `Aomi/Aomi/Views/SessionList/SessionListView.swift`
- Create: `Aomi/Aomi/Views/SessionList/SessionRowView.swift`

**Step 1: Create SessionListViewModel.swift**

```swift
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
```

**Step 2: Create SessionListView.swift**

```swift
import SwiftUI

struct SessionListView: View {
    @Environment(AomiAPIClient.self) private var apiClient
    @Environment(ParaWalletService.self) private var walletService
    @State private var viewModel: SessionListViewModel?
    @State private var selectedSessionId: String?
    @State private var showWalletSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    sessionList(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Aomi")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showWalletSheet = true
                    } label: {
                        if let address = walletService.primaryAddress {
                            Text(truncateAddress(address))
                                .font(.caption.monospaced())
                        } else {
                            Image(systemName: "wallet.bifold")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let viewModel else { return }
                        let id = viewModel.createNewSession()
                        selectedSessionId = id
                    } label: {
                        Image(systemName: "plus.message")
                    }
                }
            }
            .navigationDestination(item: $selectedSessionId) { sessionId in
                ChatView(sessionId: sessionId)
            }
            .sheet(isPresented: $showWalletSheet) {
                WalletManagementSheet()
            }
        }
        .task {
            let vm = SessionListViewModel(apiClient: apiClient)
            viewModel = vm
            await vm.loadSessions()
        }
    }

    @ViewBuilder
    private func sessionList(_ viewModel: SessionListViewModel) -> some View {
        if viewModel.sessions.isEmpty && !viewModel.isLoading {
            ContentUnavailableView {
                Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Start a new conversation with Aomi")
            }
        } else {
            List {
                ForEach(viewModel.sessions) { session in
                    SessionRowView(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSessionId = session.id
                        }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let session = viewModel.sessions[index]
                        Task { await viewModel.archiveSession(id: session.id) }
                    }
                }
            }
            .refreshable {
                await viewModel.loadSessions()
            }
        }
    }

    private func truncateAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}
```

**Step 3: Create SessionRowView.swift**

```swift
import SwiftUI

struct SessionRowView: View {
    let session: SessionItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle)
                    .font(.body)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
```

**Step 4: Verify build, commit**

```bash
git add Aomi/ && git commit -m "feat: add session list view"
```

---

## Task 6: Chat Core (ViewModel + Views)

**Goal:** Build the main chat interface -- streaming messages, tool step display, input bar.

**Files:**
- Create: `Aomi/Aomi/ViewModels/ChatViewModel.swift`
- Create: `Aomi/Aomi/Views/Chat/ChatView.swift`
- Create: `Aomi/Aomi/Views/Chat/ChatMessageView.swift`
- Create: `Aomi/Aomi/Views/Chat/UserBubbleView.swift`
- Create: `Aomi/Aomi/Views/Chat/AssistantMessageView.swift`
- Create: `Aomi/Aomi/Views/Chat/ChatInputBar.swift`
- Create: `Aomi/Aomi/Views/Chat/ThinkingShimmerView.swift`
- Create: `Aomi/Aomi/Views/Chat/ToolStepRow.swift`
- Create: `Aomi/Aomi/Views/Chat/ToolDetailSheet.swift`

**Step 1: Create ChatViewModel.swift**

The core logic. Sends messages to aomi API, polls for state while processing, converts API responses to ChatMessage models.

```swift
import Foundation
import SwiftData

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isStreaming = false
    var activeToolLabel: String?
    var currentAssistantMessageId: UUID?

    let sessionId: String
    private let apiClient: AomiAPIClient
    private let walletService: ParaWalletService
    private var pollTask: Task<Void, Never>?
    private var lastMessageCount = 0

    init(sessionId: String, apiClient: AomiAPIClient, walletService: ParaWalletService) {
        self.sessionId = sessionId
        self.apiClient = apiClient
        self.walletService = walletService
        apiClient.sessionId = sessionId
        apiClient.publicKey = walletService.primaryAddress
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        // Add user message
        let userMsg = ChatMessage(role: .user, content: [.text(text)])
        messages.append(userMsg)

        // Start processing
        isStreaming = true
        activeToolLabel = "Thinking..."

        pollTask?.cancel()
        pollTask = Task {
            do {
                // Send message and get initial response
                let userState = buildUserState()
                let response = try await apiClient.sendMessage(text, userState: userState)
                processResponse(response)

                // Poll while processing
                while !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(500))
                    let state = try await apiClient.getState(userState: userState)
                    processResponse(state)
                    if !state.isProcessing { break }
                }
            } catch {
                if !Task.isCancelled {
                    let errorMsg = ChatMessage(role: .system, content: [.error(error.localizedDescription)])
                    messages.append(errorMsg)
                }
            }
            isStreaming = false
            activeToolLabel = nil
        }
    }

    func interrupt() {
        pollTask?.cancel()
        Task {
            try? await apiClient.interrupt()
            isStreaming = false
            activeToolLabel = nil
        }
    }

    func loadHistory() async {
        do {
            let response = try await apiClient.getState()
            processResponse(response)
        } catch {
            // No history available
        }
    }

    // MARK: - Response Processing

    private func processResponse(_ response: SessionResponse) {
        // Convert API messages to ChatMessages, replacing entire list
        // (aomi backend returns full message history each time)
        var newMessages: [ChatMessage] = []
        for apiMsg in response.messages {
            let role: ChatRole = switch apiMsg.sender {
            case .user: .user
            case .agent: .assistant
            case .system: .system
            }
            var content: [ChatContent] = []

            // Check if tool_result contains a widget
            if let toolResult = apiMsg.toolResult {
                if let widget = parseWidget(topic: toolResult.topic, content: toolResult.content) {
                    content.append(.widget(widget))
                } else if !toolResult.content.isEmpty {
                    content.append(.text(apiMsg.content))
                }
            }

            if !apiMsg.content.isEmpty && content.isEmpty {
                content.append(.text(apiMsg.content))
            }

            newMessages.append(ChatMessage(role: role, content: content))
        }

        // Update if message count OR last message content changed (for streaming)
        let lastMsgContent = messages.last?.textContent ?? ""
        let newLastMsgContent = newMessages.last?.textContent ?? ""
        
        if newMessages.count != lastMessageCount || lastMsgContent != newLastMsgContent {
            messages = newMessages
            lastMessageCount = newMessages.count
            if let last = newMessages.last, last.role == .assistant {
                currentAssistantMessageId = last.id
            }
        }

        // Update streaming label
        if response.isProcessing {
            activeToolLabel = "Processing..."
        }
    }

    private func parseWidget(topic: String, content: String) -> WidgetPayload? {
        let widgetTopics = [
            WidgetPayload.portfolioOverview,
            WidgetPayload.tokenBalance,
            WidgetPayload.priceChart,
            WidgetPayload.defiPosition,
            WidgetPayload.transactionConfirmation,
        ]
        guard widgetTopics.contains(topic) else { return nil }
        guard let data = content.data(using: .utf8),
              let jsonData = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return nil
        }
        return WidgetPayload(widgetType: topic, data: jsonData)
    }

    private func buildUserState() -> APIUserState {
        APIUserState(
            address: walletService.primaryAddress,
            chainId: 1,
            isConnected: walletService.isLoggedIn,
            ensName: nil
        )
    }

    // MARK: - Persistence

    func saveDraft(modelContext: ModelContext) {
        // Save draft input text to SwiftData
        let descriptor = FetchDescriptor<PersistedChatSession>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        if let session = try? modelContext.fetch(descriptor).first {
            session.draftInputText = inputText
        }
    }

    func loadDraft(modelContext: ModelContext) {
        let sid = sessionId
        let descriptor = FetchDescriptor<PersistedChatSession>(
            predicate: #Predicate { $0.sessionId == sid }
        )
        if let session = try? modelContext.fetch(descriptor).first {
            inputText = session.draftInputText ?? ""
        }
    }
}
```

**Step 2: Create ChatView.swift**

```swift
import SwiftUI

struct ChatView: View {
    let sessionId: String
    @Environment(AomiAPIClient.self) private var apiClient
    @Environment(ParaWalletService.self) private var walletService
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if let viewModel {
                chatContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let vm = ChatViewModel(
                sessionId: sessionId,
                apiClient: apiClient,
                walletService: walletService
            )
            viewModel = vm
            vm.loadDraft(modelContext: modelContext)
            await vm.loadHistory()
        }
    }

    @ViewBuilder
    private func chatContent(_ viewModel: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageView(
                            message: message,
                            isStreaming: viewModel.isStreaming && message.id == viewModel.currentAssistantMessageId
                        )
                        .id(message.id)
                    }
                    if viewModel.isStreaming {
                        ThinkingShimmerView(label: viewModel.activeToolLabel ?? "Thinking...")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                proxy.scrollTo("bottom")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatInputBar(
                text: Bindable(viewModel).inputText,
                isStreaming: viewModel.isStreaming,
                onSend: {
                    isInputFocused = false
                    viewModel.sendMessage()
                },
                onInterrupt: {
                    viewModel.interrupt()
                },
                isFocused: $isInputFocused
            )
        }
        .onChange(of: viewModel.inputText) {
            viewModel.saveDraft(modelContext: modelContext)
        }
    }
}
```

**Step 3: Create ChatMessageView.swift**

```swift
import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    var isStreaming: Bool = false

    var body: some View {
        switch message.role {
        case .user:
            UserBubbleView(message: message)
        case .assistant:
            AssistantMessageView(message: message, isStreaming: isStreaming)
        case .system:
            systemMessage
        }
    }

    private var systemMessage: some View {
        HStack {
            Spacer()
            if let text = message.content.first, case .text(let str) = text {
                Text(str)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
        }
    }
}
```

**Step 4: Create UserBubbleView.swift**

```swift
import SwiftUI

struct UserBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Text(message.textContent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)
        }
    }
}
```

**Step 5: Create AssistantMessageView.swift**

```swift
import MarkdownUI
import SwiftUI

struct AssistantMessageView: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    @State private var selectedToolCard: ToolUseCard?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(message.content) { contentBlock in
                    switch contentBlock {
                    case .text(let text):
                        Markdown(text)
                            .textSelection(.enabled)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16))

                    case .toolUse(let card):
                        if card.result != nil {
                            ToolStepRow(card: card) { selectedToolCard = card }
                        }

                    case .toolResult:
                        EmptyView()

                    case .widget(let payload):
                        WidgetRenderer(payload: payload)

                    case .error(let errorMessage):
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Spacer(minLength: 60)
        }
        .sheet(item: $selectedToolCard) { card in
            ToolDetailSheet(card: card)
        }
    }
}
```

**Step 6: Create ChatInputBar.swift**

```swift
import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onInterrupt: () -> Void
    var isFocused: FocusState<Bool>.Binding

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message aomi...", text: $text, axis: .vertical)
                .focused(isFocused)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: 36)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))

            if isStreaming {
                Button(action: onInterrupt) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isEmpty ? .gray : Color.accentColor)
            }
            .disabled(isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
```

**Step 7: Create ThinkingShimmerView.swift**

Adapted directly from Wisp:

```swift
import SwiftUI

struct ThinkingShimmerView: View {
    let label: String
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        HStack(spacing: 8) {
            PulsingDot()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .overlay(shimmerGradient)
                .mask(
                    Text(label)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                )
                .animation(.easeInOut(duration: 0.2), value: label)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                shimmerOffset = 2
            }
        }
    }

    private var shimmerGradient: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .white.opacity(0.4), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.4)
            .offset(x: geo.size.width * shimmerOffset)
        }
    }
}

private struct PulsingDot: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 6, height: 6)
            .scaleEffect(isAnimating ? 1.3 : 0.8)
            .opacity(isAnimating ? 1 : 0.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
```

**Step 8: Create ToolStepRow.swift**

```swift
import SwiftUI

struct ToolStepRow: View {
    let card: ToolUseCard
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: card.iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(card.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let elapsed = card.elapsedString {
                    Text(elapsed)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
```

**Step 9: Create ToolDetailSheet.swift**

```swift
import SwiftUI

struct ToolDetailSheet: View {
    let card: ToolUseCard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: card.iconName)
                        Text(card.toolName)
                            .font(.headline)
                        Spacer()
                        if let elapsed = card.elapsedString {
                            Text(elapsed)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(card.input.prettyString)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    // Output
                    if let result = card.result {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(result.displayContent)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Tool Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
```

**Step 10: Verify build, commit**

```bash
git add Aomi/ && git commit -m "feat: add chat core - view model, views, streaming"
```

---

## Task 7: Rich Widgets

**Goal:** Build all 5 widget types rendered inline in chat.

**Files:**
- Create: `Aomi/Aomi/Views/Chat/Widgets/WidgetRenderer.swift`
- Create: `Aomi/Aomi/Views/Chat/Widgets/PortfolioOverviewWidget.swift`
- Create: `Aomi/Aomi/Views/Chat/Widgets/TokenBalanceWidget.swift`
- Create: `Aomi/Aomi/Views/Chat/Widgets/PriceChartWidget.swift`
- Create: `Aomi/Aomi/Views/Chat/Widgets/DeFiPositionWidget.swift`
- Create: `Aomi/Aomi/Views/Chat/Widgets/DeFiPositionDetailSheet.swift`
- Create: `Aomi/Aomi/Views/Chat/Widgets/TransactionConfirmationWidget.swift`

**Step 1: Create WidgetRenderer.swift**

Routes widget payloads to the correct view:

```swift
import SwiftUI

struct WidgetRenderer: View {
    let payload: WidgetPayload

    var body: some View {
        switch payload.widgetType {
        case WidgetPayload.portfolioOverview:
            PortfolioOverviewWidget(data: payload.data)
        case WidgetPayload.tokenBalance:
            TokenBalanceWidget(data: payload.data)
        case WidgetPayload.priceChart:
            PriceChartWidget(data: payload.data)
        case WidgetPayload.defiPosition:
            DeFiPositionWidget(data: payload.data)
        case WidgetPayload.transactionConfirmation:
            TransactionConfirmationWidget(data: payload.data)
        default:
            // Unknown widget -- render raw JSON
            Text(payload.data.prettyString)
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
```

**Step 2: Create PortfolioOverviewWidget.swift**

```swift
import Charts
import SwiftUI

struct PortfolioOverviewWidget: View {
    let data: JSONValue
    @State private var selectedToken: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Portfolio")
                    .font(.headline)
                Spacer()
                Text(totalValue)
                    .font(.title2.bold())
            }

            // Token list
            ForEach(tokens, id: \.symbol) { token in
                Button {
                    selectedToken = token.symbol
                } label: {
                    HStack(spacing: 10) {
                        // Token icon
                        AsyncImage(url: AppConfig.tokenIconURL(symbol: token.symbol.lowercased())) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Circle().fill(Color(.systemGray4))
                        }
                        .frame(width: 24, height: 24)

                        Text(token.symbol)
                            .font(.subheadline.bold())
                            .frame(width: 50, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text(token.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        // Sparkline
                        if !token.sparkline.isEmpty {
                            Chart {
                                ForEach(Array(token.sparkline.enumerated()), id: \.offset) { i, val in
                                    LineMark(x: .value("", i), y: .value("", val))
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(width: 50, height: 24)
                        }
                        VStack(alignment: .trailing) {
                            Text(token.balance)
                                .font(.subheadline)
                            Text(token.usdValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        .sheet(item: $selectedToken) { symbol in
            // Show price chart detail for selected token
            if let token = tokens.first(where: { $0.symbol == symbol }) {
                PriceChartDetailSheet(tokenSymbol: token.symbol, sparkline: token.sparkline)
            }
        }
    }

    private var totalValue: String {
        data["total_value"]?.stringValue ?? "$0.00"
    }

    private var tokens: [TokenRow] {
        guard case .array(let items) = data["tokens"] else { return [] }
        return items.compactMap { item in
            guard let symbol = item["symbol"]?.stringValue,
                  let name = item["name"]?.stringValue,
                  let balance = item["balance"]?.stringValue,
                  let usdValue = item["usd_value"]?.stringValue else { return nil }
            let sparkline: [Double] = (item["sparkline"]?.arrayValue ?? []).compactMap(\.numberValue)
            return TokenRow(symbol: symbol, name: name, balance: balance, usdValue: usdValue, sparkline: sparkline)
        }
    }
}

private struct TokenRow {
    let symbol: String
    let name: String
    let balance: String
    let usdValue: String
    let sparkline: [Double]
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
```

**Step 3: Create TokenBalanceWidget.swift**

```swift
import Charts
import SwiftUI

struct TokenBalanceWidget: View {
    let data: JSONValue

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(symbol)
                    .font(.headline)
                Text(balance)
                    .font(.title3.bold())
                Text(usdValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !sparkline.isEmpty {
                Chart {
                    ForEach(Array(sparkline.enumerated()), id: \.offset) { i, val in
                        LineMark(x: .value("", i), y: .value("", val))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 80, height: 40)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }

    private var symbol: String { data["symbol"]?.stringValue ?? "" }
    private var balance: String { data["balance"]?.stringValue ?? "0" }
    private var usdValue: String { data["usd_value"]?.stringValue ?? "$0.00" }
    private var sparkline: [Double] {
        (data["sparkline"]?.arrayValue ?? []).compactMap(\.numberValue)
    }
}
```

**Step 4: Create PriceChartWidget.swift**

```swift
import Charts
import SwiftUI

struct PriceChartWidget: View {
    let data: JSONValue
    @State private var selectedPeriod = "1W"
    @State private var selectedIndex: Int?

    private let periods = ["1D", "1W", "1M", "1Y"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(symbol)
                    .font(.headline)
                Spacer()
                Text(selectedIndex.map { String(format: "$%.2f", chartData[$0]) } ?? currentPrice)
                    .font(.title3.bold())
            }

            Chart {
                ForEach(Array(chartData.enumerated()), id: \.offset) { i, point in
                    LineMark(
                        x: .value("Time", i),
                        y: .value("Price", point)
                    )
                    .foregroundStyle(Color.accentColor)
                    AreaMark(
                        x: .value("Time", i),
                        y: .value("Price", point)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.accentColor.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXSelection(value: $selectedIndex)
            .frame(height: 160)

            // Period selector
            HStack {
                ForEach(periods, id: \.self) { period in
                    Button(period) { selectedPeriod = period }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedPeriod == period ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(selectedPeriod == period ? .primary : .secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }

    private var symbol: String { data["symbol"]?.stringValue ?? "" }
    private var currentPrice: String { data["current_price"]?.stringValue ?? "$0.00" }
    private var chartData: [Double] {
        (data["chart_data"]?.arrayValue ?? []).compactMap(\.numberValue)
    }
}

struct PriceChartDetailSheet: View {
    let tokenSymbol: String
    let sparkline: [Double]

    var body: some View {
        NavigationStack {
            VStack {
                Chart {
                    ForEach(Array(sparkline.enumerated()), id: \.offset) { i, val in
                        LineMark(x: .value("", i), y: .value("", val))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: 200)
                .padding()
            }
            .navigationTitle(tokenSymbol)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
```

**Step 5: Create DeFiPositionWidget.swift + detail sheet**

```swift
import SwiftUI

struct DeFiPositionWidget: View {
    let data: JSONValue
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(protocolName)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(positionName)
                        .font(.subheadline.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currentValue)
                        .font(.subheadline.bold())
                    Text(pnl)
                        .font(.caption)
                        .foregroundStyle(pnlIsPositive ? .green : .red)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            DeFiPositionDetailSheet(data: data)
        }
    }

    private var protocolName: String { data["protocol"]?.stringValue ?? "" }
    private var positionName: String { data["position_name"]?.stringValue ?? "" }
    private var currentValue: String { data["current_value"]?.stringValue ?? "$0.00" }
    private var pnl: String { data["pnl"]?.stringValue ?? "$0.00" }
    private var pnlIsPositive: Bool { !(pnl.hasPrefix("-")) }
}
```

```swift
import Charts
import SwiftUI

struct DeFiPositionDetailSheet: View {
    let data: JSONValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data["protocol"]?.stringValue ?? "")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(data["position_name"]?.stringValue ?? "")
                            .font(.title2.bold())
                    }

                    // Value chart
                    if !valueHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Value Over Time")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Chart {
                                ForEach(Array(valueHistory.enumerated()), id: \.offset) { i, val in
                                    LineMark(x: .value("", i), y: .value("", val))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 160)
                        }
                    }

                    // Key metrics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metrics")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        metricRow("Current Value", data["current_value"]?.stringValue)
                        metricRow("Deposited", data["deposited_value"]?.stringValue)
                        metricRow("PnL", data["pnl"]?.stringValue)
                        metricRow("APY", data["apy"]?.stringValue)
                        metricRow("Health Factor", data["health_factor"]?.stringValue)
                        metricRow("Liquidation Price", data["liquidation_price"]?.stringValue)
                    }

                    // Composition
                    if case .array(let tokens) = data["composition"] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Composition")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                                HStack {
                                    Text(token["symbol"]?.stringValue ?? "")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(token["amount"]?.stringValue ?? "")
                                        .font(.subheadline)
                                    Text(token["percentage"]?.stringValue ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Position Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    private var valueHistory: [Double] {
        (data["value_history"]?.arrayValue ?? []).compactMap(\.numberValue)
    }

    @ViewBuilder
    private func metricRow(_ label: String, _ value: String?) -> some View {
        if let value {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline.bold())
            }
        }
    }
}
```

**Step 6: Create TransactionConfirmationWidget.swift**

```swift
import SwiftUI

struct TransactionConfirmationWidget: View {
    let data: JSONValue
    @Environment(ParaWalletService.self) private var walletService
    @State private var isSigning = false
    @State private var result: TransactionResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.up.right.circle")
                    .foregroundStyle(.orange)
                Text("Transaction Request")
                    .font(.headline)
            }

            // Details
            VStack(alignment: .leading, spacing: 6) {
                detailRow("Action", description)
                detailRow("From", truncate(from))
                detailRow("To", truncate(to))
                detailRow("Value", value)
                detailRow("Gas (est)", gas)
                detailRow("Chain", chain)
            }
            .font(.subheadline)

            // Actions
            if let result {
                Label(
                    result == .signed ? "Signed" : "Rejected",
                    systemImage: result == .signed ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(result == .signed ? .green : .red)
                .font(.subheadline.bold())
            } else {
                HStack(spacing: 12) {
                    Button("Reject") {
                        result = .rejected
                    }
                    .buttonStyle(.bordered)

                    Button {
                        signTransaction()
                    } label: {
                        if isSigning {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSigning)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func signTransaction() {
        guard let walletId = walletService.wallets.first(where: { $0.type == .evm })?.id,
              let message = data["sign_data"]?.stringValue else { return }
        isSigning = true
        Task {
            do {
                _ = try await walletService.signMessage(walletId: walletId, message: message)
                result = .signed
            } catch {
                result = .rejected
            }
            isSigning = false
        }
    }

    private var description: String { data["description"]?.stringValue ?? "" }
    private var from: String { data["from"]?.stringValue ?? "" }
    private var to: String { data["to"]?.stringValue ?? "" }
    private var value: String { data["value"]?.stringValue ?? "0" }
    private var gas: String { data["gas"]?.stringValue ?? "" }
    private var chain: String { data["chain"]?.stringValue ?? "" }

    private func truncate(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    enum TransactionResult {
        case signed, rejected
    }
}
```

**Step 7: Verify build, commit**

```bash
git add Aomi/ && git commit -m "feat: add rich widgets - portfolio, charts, DeFi, transactions"
```

---

## Task 8: Wallet Management Views

**Goal:** Build the wallet management sheet (modal from session list).

**Files:**
- Create: `Aomi/Aomi/Views/Wallet/WalletManagementSheet.swift`
- Create: `Aomi/Aomi/Views/Wallet/WalletRowView.swift`
- Create: `Aomi/Aomi/Views/Wallet/AddWatchAddressView.swift`

**Step 1: Create WalletManagementSheet.swift**

```swift
import SwiftUI

struct WalletManagementSheet: View {
    @Environment(ParaWalletService.self) private var walletService
    @Environment(AomiAPIClient.self) private var apiClient
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WalletViewModel?
    @State private var showAddWatch = false
    @State private var showAddPara = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    walletList(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Wallets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Create Para Wallet", systemImage: "plus.circle") {
                            showAddPara = true
                        }
                        Button("Add Watch Address", systemImage: "eye") {
                            showAddWatch = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddWatch) {
                if let viewModel {
                    AddWatchAddressView { address, chain, label in
                        viewModel.addWatchAddress(address, chain: chain, label: label, modelContext: modelContext)
                        // Bind wallet to backend
                        Task { try? await apiClient.bindWallet(address: address, platform: "ios", platformUserId: "local") }
                    }
                }
            }
            .alert("Create Wallet", isPresented: $showAddPara) {
                Button("EVM") { createParaWallet(.evm) }
                Button("Solana") { createParaWallet(.solana) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Select blockchain type")
            }
        }
        .task {
            let vm = WalletViewModel(walletService: walletService)
            viewModel = vm
            await vm.loadWallets()
            vm.loadWatchAddresses(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private func walletList(_ vm: WalletViewModel) -> some View {
        List {
            if !vm.paraWallets.isEmpty {
                Section("Signing Wallets") {
                    ForEach(vm.paraWallets) { wallet in
                        WalletRowView(address: wallet.address, chain: wallet.chain, label: nil, badge: "signing")
                    }
                }
            }
            if !vm.watchAddresses.isEmpty {
                Section("Watch Only") {
                    ForEach(vm.watchAddresses) { entry in
                        WalletRowView(address: entry.address, chain: entry.chain, label: entry.label, badge: "read-only")
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            vm.removeWatchAddress(vm.watchAddresses[i], modelContext: modelContext)
                        }
                    }
                }
            }
        }
    }

    private func createParaWallet(_ type: ParaSwift.WalletType) {
        Task {
            do {
                try await walletService.createWallet(type: type)
                viewModel?.loadWallets()
            } catch {}
        }
    }
}
```

**Step 2: Create WalletRowView.swift**

```swift
import SwiftUI

struct WalletRowView: View {
    let address: String
    let chain: String
    let label: String?
    let badge: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let label {
                    Text(label)
                        .font(.subheadline.bold())
                }
                Text(truncatedAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(chain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(badge)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        badge == "signing" ? Color.green.opacity(0.15) : Color.gray.opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(badge == "signing" ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Copy Address", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = address
            }
        }
    }

    private var truncatedAddress: String {
        guard address.count > 14 else { return address }
        return "\(address.prefix(8))...\(address.suffix(6))"
    }
}
```

**Step 3: Create AddWatchAddressView.swift**

```swift
import SwiftUI

struct AddWatchAddressView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var label = ""
    @State private var chain = "EVM"
    let onAdd: (String, String, String?) -> Void

    private let chains = ["EVM", "Solana", "Cosmos"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Wallet Address", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))

                TextField("Label (optional)", text: $label)

                Picker("Chain", selection: $chain) {
                    ForEach(chains, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("Add Watch Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(address, chain, label.isEmpty ? nil : label)
                        dismiss()
                    }
                    .disabled(address.isEmpty)
                }
            }
        }
    }
}
```

**Step 4: Verify build, commit**

```bash
git add Aomi/ && git commit -m "feat: add wallet management views"
```

---

## Task 9: Onboarding & Root Navigation

**Goal:** Build the welcome screen, wallet prompt card, and wire up the root navigation.

**Files:**
- Create: `Aomi/Aomi/Views/Onboarding/WelcomeView.swift`
- Create: `Aomi/Aomi/Views/Onboarding/WalletPromptCard.swift`
- Create: `Aomi/Aomi/Views/Onboarding/AuthLoginView.swift`
- Create: `Aomi/Aomi/Views/Onboarding/AuthVerifyOTPView.swift`
- Modify: `Aomi/Aomi/App/AomiApp.swift`

**Step 1: Create WelcomeView.swift**

```swift
import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("aomi")
                .font(.largeTitle.bold())
            Text("Your AI blockchain assistant")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}
```

**Step 2: Create WalletPromptCard.swift**

This is shown inline in chat when aomi needs a wallet:

```swift
import SwiftUI

struct WalletPromptCard: View {
    var onCreateWallet: () -> Void
    var onAddWatch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wallet.bifold")
                    .foregroundStyle(.orange)
                Text("Wallet Required")
                    .font(.headline)
            }
            Text("To check balances and execute transactions, connect a wallet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Create Wallet") { onCreateWallet() }
                    .buttonStyle(.borderedProminent)
                Button("Add Address") { onAddWatch() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
```

**Step 3: Create AuthLoginView.swift**

```swift
import SwiftUI
import AuthenticationServices

struct AuthLoginView: View {
    @Environment(ParaWalletService.self) private var walletService
    @State private var authVM: AuthViewModel?
    @State private var input = ""
    @State private var showOTP = false
    @Binding var isLoggedIn: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Connect with Para")
                    .font(.title2.bold())
                Text("Enter your email or phone to create or access your embedded wallet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Email or phone", text: $input)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if let authVM, !authVM.errorMessage.isEmpty {
                    Text(authVM.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    guard let authVM else { return }
                    Task {
                        await authVM.initiateLogin(input: input)
                        if authVM.needsOTPVerification {
                            showOTP = true
                        }
                    }
                } label: {
                    if authVM?.isLoading == true {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(input.isEmpty || authVM?.isLoading == true)
            }
            .padding()
            .navigationDestination(isPresented: $showOTP) {
                if let authVM {
                    AuthVerifyOTPView(authVM: authVM, isLoggedIn: $isLoggedIn)
                }
            }
        }
        .task {
            authVM = AuthViewModel(walletService: walletService)
        }
    }
}
```

**Step 4: Create AuthVerifyOTPView.swift**

```swift
import SwiftUI

struct AuthVerifyOTPView: View {
    let authVM: AuthViewModel
    @Binding var isLoggedIn: Bool
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter Verification Code")
                .font(.title2.bold())
            Text("Check your email or phone for the code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Code", text: $code)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if !authVM.errorMessage.isEmpty {
                Text(authVM.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    let verified = await authVM.verifyOTP(code: code)
                    if verified {
                        isLoggedIn = true
                    }
                }
            } label: {
                if authVM.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Verify").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(code.count < 4 || authVM.isLoading)
        }
        .padding()
    }
}
```

**Step 5: Update AomiApp.swift -- wire everything together**

```swift
import SwiftData
import SwiftUI
import ParaSwift

@main
struct AomiApp: App {
    @State private var apiClient = AomiAPIClient()
    @State private var walletService: ParaWalletService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let apiKey = KeychainService.load(key: "para_api_key") ?? ""
        _walletService = State(wrappedValue: ParaWalletService(
            environment: .beta,
            apiKey: apiKey,
            appScheme: AppConfig.paraAppScheme
        ))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else {
                    SessionListView()
                }
            }
            .environment(apiClient)
            .environment(walletService)
            .task {
                await walletService.checkAuthStatus()
                if let address = walletService.primaryAddress {
                    apiClient.publicKey = address
                }
            }
        }
        .modelContainer(for: [PersistedChatSession.self, WalletEntry.self])
    }
}
```

**Step 6: Verify build, commit**

```bash
git add Aomi/ && git commit -m "feat: add onboarding, auth views, and root navigation"
```

---

## Task 10: Integration Testing & Polish

**Goal:** End-to-end build verification, fix compilation issues, and create a working app.

**Step 1: Full build**

```bash
cd Aomi
xcodegen generate
xcodebuild -project Aomi.xcodeproj -scheme Aomi -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Fix any compilation errors.

**Step 2: Run all tests**

```bash
xcodebuild test -project Aomi.xcodeproj -scheme AomiTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test|PASS|FAIL"
```

**Step 3: Fix any `@Bindable` / `@Observable` / `@Environment` issues**

Common issues to check:
- `@Bindable` only works with `@Observable` types
- `@Environment` requires the value to be passed with `.environment()` in the view hierarchy
- `ParaSwift` import may have naming conflicts

**Step 4: Verify simulator launch**

```bash
xcodebuild -project Aomi.xcodeproj -scheme Aomi -destination 'platform=iOS Simulator,name=iPhone 16' -sdk iphonesimulator build 2>&1 | tail -3
```

**Step 5: Final commit**

```bash
git add Aomi/ && git commit -m "feat: complete Aomi iOS v1 scaffold"
```

---

## Dependency Summary

| Package | Version | Purpose |
|---------|---------|---------|
| ParaSwift | 2.6.0 exact | Embedded wallet SDK |
| MarkdownUI | >= 2.4.0 | Markdown rendering in chat |

No other third-party dependencies. Swift Charts is a system framework.

## API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/chat` | POST | Send message |
| `/api/state` | GET | Poll for updates |
| `/api/interrupt` | POST | Cancel processing |
| `/api/sessions` | GET | List sessions |
| `/api/sessions` | POST | Create session |
| `/api/sessions/:id` | PATCH | Rename session |
| `/api/sessions/:id/archive` | POST | Archive session |
| `/api/wallet/bind` | POST | Bind wallet |
