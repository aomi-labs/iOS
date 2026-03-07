import Foundation

struct SessionResponse: Codable, Sendable {
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

struct APIMessage: Codable, Sendable, Equatable {
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

    enum MessageSender: String, Codable, Sendable {
        case user
        case agent
        case system
    }
}

struct ToolResultTuple: Codable, Sendable, Equatable {
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

struct APIUserState: Codable, Sendable {
    let address: String?
    let chainId: UInt64?
    let isConnected: Bool
    let ensName: String?
    let pendingTransactions: [APIPendingTransaction]

    init(address: String? = nil, chainId: UInt64? = nil, isConnected: Bool = false, ensName: String? = nil, pendingTransactions: [APIPendingTransaction] = []) {
        self.address = address
        self.chainId = chainId
        self.isConnected = isConnected
        self.ensName = ensName
        self.pendingTransactions = pendingTransactions
    }
}

struct APIPendingTransaction: Codable, Sendable, Identifiable {
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

struct WalletTxRequest: Identifiable, Equatable {
    let id: String
    let to: String
    let value: String?
    let data: String?
    let chainId: Int

    init(id: String = UUID().uuidString, to: String, value: String? = nil, data: String? = nil, chainId: Int = 1) {
        self.id = id
        self.to = to
        self.value = value
        self.data = data
        self.chainId = chainId
    }
}

struct APIModelInfo: Codable, Sendable, Identifiable {
    let rig: String
    var id: String { rig }

    enum CodingKeys: String, CodingKey {
        case rig
    }

    init(rig: String) {
        self.rig = rig
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let rig = try? container.decode(String.self) {
            self.rig = rig
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        rig = try container.decode(String.self, forKey: .rig)
    }
}

struct APINamespace: Codable, Sendable, Identifiable {
    let name: String
    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
    }

    init(name: String) {
        self.name = name
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let name = try? container.decode(String.self) {
            self.name = name
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
    }
}

struct APIEvent: Codable, Sendable, Identifiable {
    let id: String
    let type: String
    let timestamp: String
    let data: JSONValue

    enum CodingKeys: String, CodingKey {
        case id, type, timestamp, data
    }
}

struct APISessionItem: Codable, Sendable, Identifiable {
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
