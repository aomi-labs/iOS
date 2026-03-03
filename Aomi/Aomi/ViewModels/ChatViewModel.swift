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
