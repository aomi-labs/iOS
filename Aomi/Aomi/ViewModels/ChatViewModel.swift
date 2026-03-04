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
    var generatedTitle: String?
    var pendingWalletRequests: [WalletTxRequest] = []
    private var processedSystemEventIds: Set<String> = []

    let sessionId: String
    private let apiClient: AomiAPIClient
    private let walletService: ParaWalletService
    private var pollTask: Task<Void, Never>?
    private var lastMessageCount = 0
    private var hasGeneratedTitle = false
    private let titleGenerator = SessionTitleGenerator()

    init(sessionId: String, apiClient: AomiAPIClient, walletService: ParaWalletService) {
        self.sessionId = sessionId
        self.apiClient = apiClient
        self.walletService = walletService
        apiClient.sessionId = sessionId
        if apiClient.publicKey == nil {
            apiClient.publicKey = walletService.primaryAddress
        }
        observeTransactionCompletions()
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
                // Generate title after first complete response
                await generateTitleIfNeeded()
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

    // MARK: - Title Generation

    private func generateTitleIfNeeded() async {
        guard !hasGeneratedTitle else { return }

        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }
        guard let firstUser = userMessages.first,
              let firstAssistant = assistantMessages.first else { return }

        hasGeneratedTitle = true

        let userText = firstUser.textContent
        let assistantText = firstAssistant.textContent
        guard !userText.isEmpty, !assistantText.isEmpty else { return }

        if let title = await titleGenerator.generateTitle(
            sessionId: sessionId,
            userMessage: userText,
            assistantResponse: assistantText
        ) {
            generatedTitle = title
            try? await apiClient.renameSession(sessionId: sessionId, title: title)
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
                    content.append(.text(toolResult.content))
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

        // Process system events for wallet tx requests
        processSystemEvents(response.systemEvents)
    }

    private func processSystemEvents(_ events: [JSONValue]) {
        for event in events {
            // System events have shape: {"InlineCall": {"type": "...", "payload": {...}}}
            guard let inlineCall = event["InlineCall"],
                  let type = inlineCall["type"]?.stringValue,
                  type == "wallet_tx_request",
                  let payload = inlineCall["payload"] else {
                continue
            }

            guard let to = payload["to"]?.stringValue else { continue }

            // Deduplicate using to+value+data as a fingerprint
            let value = payload["value"]?.stringValue
            let data = payload["data"]?.stringValue
            let chainIdNum: Int
            if let cid = payload["chainId"]?.numberValue {
                chainIdNum = Int(cid)
            } else if let cidStr = payload["chain_id"]?.stringValue, let cid = Int(cidStr) {
                chainIdNum = cid
            } else if let cid = payload["chain_id"]?.numberValue {
                chainIdNum = Int(cid)
            } else {
                chainIdNum = 1
            }

            let fingerprint = "\(to)-\(value ?? "")-\(data ?? "")-\(chainIdNum)"
            guard !processedSystemEventIds.contains(fingerprint) else { continue }
            processedSystemEventIds.insert(fingerprint)

            let txRequest = WalletTxRequest(to: to, value: value, data: data, chainId: chainIdNum)
            pendingWalletRequests.append(txRequest)

            // Only inject a widget if the tool_result path didn't already render one
            let alreadyRendered = messages.contains { msg in
                msg.content.contains { content in
                    if case .widget(let w) = content,
                       w.widgetType == WidgetPayload.transactionConfirmation,
                       w.data["to"]?.stringValue == to {
                        return true
                    }
                    return false
                }
            }
            if !alreadyRendered {
                let widgetData = buildTxWidgetData(payload: payload, chainId: chainIdNum)
                let widget = WidgetPayload(widgetType: WidgetPayload.transactionConfirmation, data: widgetData)
                let widgetMsg = ChatMessage(role: .assistant, content: [.widget(widget)])
                messages.append(widgetMsg)
            }
        }
    }

    private func buildTxWidgetData(payload: JSONValue, chainId: Int) -> JSONValue {
        var dict: [String: JSONValue] = [:]
        if let to = payload["to"]?.stringValue { dict["to"] = .string(to) }
        if let from = payload["from"]?.stringValue { dict["from"] = .string(from) }
        if let value = payload["value"]?.stringValue { dict["value"] = .string(value) }
        if let data = payload["data"]?.stringValue { dict["data"] = .string(data) }
        if let gas = payload["gas"]?.stringValue { dict["gas"] = .string(gas) }
        if let desc = payload["description"]?.stringValue { dict["description"] = .string(desc) }
        dict["chain_id"] = .string(String(chainId))
        dict["status"] = .string("pending_approval")
        let chainName = ChainConfig.supported[chainId]?.name ?? "ethereum"
        dict["chain_name"] = .string(chainName)
        return .object(dict)
    }

    private func parseWidget(topic: String, content: String) -> WidgetPayload? {
        let widgetTopics = [
            WidgetPayload.portfolioOverview,
            WidgetPayload.tokenBalance,
            WidgetPayload.priceChart,
            WidgetPayload.defiPosition,
            WidgetPayload.transactionConfirmation,
        ]

        guard let data = content.data(using: .utf8),
              let jsonData = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return nil
        }

        // Match by exact topic or detect transaction by content shape
        let widgetType: String
        if widgetTopics.contains(topic) {
            widgetType = topic
        } else if jsonData["status"]?.stringValue == "pending_approval" {
            widgetType = WidgetPayload.transactionConfirmation
        } else {
            return nil
        }

        return WidgetPayload(widgetType: widgetType, data: jsonData)
    }

    private func buildUserState() -> APIUserState {
        APIUserState(
            address: apiClient.publicKey,
            chainId: 1,
            isConnected: walletService.isLoggedIn,
            ensName: nil
        )
    }

    // MARK: - Transaction Lifecycle

    private var txNotificationObserver: Any?

    func observeTransactionCompletions() {
        txNotificationObserver = NotificationCenter.default.addObserver(
            forName: .transactionCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumePolling()
            }
        }
    }

    private func resumePolling() {
        guard !isStreaming else { return }
        isStreaming = true
        activeToolLabel = "Processing..."
        pollTask?.cancel()
        pollTask = Task {
            do {
                let userState = buildUserState()
                try await Task.sleep(for: .milliseconds(500))
                while !Task.isCancelled {
                    let state = try await apiClient.getState(userState: userState)
                    processResponse(state)
                    if !state.isProcessing { break }
                    try await Task.sleep(for: .milliseconds(500))
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

    // MARK: - Persistence

    func saveDraft(modelContext: ModelContext) {
        let sid = sessionId
        let descriptor = FetchDescriptor<PersistedChatSession>(
            predicate: #Predicate { $0.sessionId == sid }
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
