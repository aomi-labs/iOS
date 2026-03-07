import Foundation
import OSLog
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
    var availableModels: [APIModelInfo] = []
    var availableNamespaces: [APINamespace] = []
    var selectedModel: String? {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    var selectedNamespace: String? {
        didSet { UserDefaults.standard.set(selectedNamespace, forKey: "selectedNamespace") }
    }
    var selectedNetwork: Int {
        didSet { UserDefaults.standard.set(selectedNetwork, forKey: "selectedNetwork") }
    }
    private var processedSystemEventIds: Set<String> = []

    let sessionId: String
    private let apiClient: AomiAPIClient
    private let walletService: ParaWalletService
    private var pollTask: Task<Void, Never>?
    private var sseTask: Task<Void, Never>?
    private var sseWatchdogTask: Task<Void, Never>?
    private var apiMessageCount = 0
    private var renderedAPIMessages: [APIMessage] = []
    private var activeLatencyTrace: ChatLatencyTrace?
    private var lastStreamingUpdateSource: String?
    private var lastStreamingUpdateAt: TimeInterval?
    private var hasGeneratedTitle = false
    private var draftSession: PersistedChatSession?
    private var draftSaveTask: Task<Void, Never>?
    private let titleGenerator = SessionTitleGenerator()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.aomi.Aomi",
        category: "ChatLatency"
    )

    init(sessionId: String, apiClient: AomiAPIClient, walletService: ParaWalletService) {
        self.sessionId = sessionId
        self.apiClient = apiClient
        self.walletService = walletService
        apiClient.sessionId = sessionId
        if apiClient.publicKey == nil {
            apiClient.publicKey = walletService.primaryAddress
        }
        selectedModel = UserDefaults.standard.string(forKey: "selectedModel")
        selectedNamespace = UserDefaults.standard.string(forKey: "selectedNamespace")
        let storedNetwork = UserDefaults.standard.integer(forKey: "selectedNetwork")
        selectedNetwork = storedNetwork != 0 ? storedNetwork : 1
        observeTransactionCompletions()
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        // Add user message at the API boundary so processResponse updates in-place
        let userMsg = ChatMessage(role: .user, content: [.text(text)])
        messages.insert(userMsg, at: apiMessageCount)
        apiMessageCount += 1

        // Start processing
        isStreaming = true
        activeToolLabel = "Thinking..."
        startLatencyTrace(prompt: text)

        // SSE is already listening -- just fire the POST.
        // The persistent SSE will handle streaming updates and clear isStreaming.
        pollTask?.cancel()
        pollTask = Task {
            do {
                let userState = buildUserState()
                let response = try await apiClient.sendMessage(text, namespace: selectedNamespace, userState: userState)
                processResponse(response, source: "post")

                if !response.isProcessing {
                    // Quick response, no streaming needed
                    isStreaming = false
                    activeToolLabel = nil
                    finishLatencyTrace(reason: "completed_post")
                    await generateTitleIfNeeded()
                } else if !apiClient.isSSEReadyForStreaming {
                    // The SSE task exists, but the stream has not delivered a
                    // usable session response yet. Poll immediately instead of
                    // waiting on a connection that may still be handshaking.
                    await pollUntilDone(userState: userState)
                    isStreaming = false
                    activeToolLabel = nil
                    finishLatencyTrace(reason: "completed_poll_until_sse_ready")
                    await generateTitleIfNeeded()
                } else {
                    scheduleSSEWatchdog(userState: userState)
                }
                // Otherwise SSE is connected and will handle the rest
            } catch {
                if !Task.isCancelled {
                    let errorMsg = ChatMessage(role: .system, content: [.error(error.localizedDescription)])
                    messages.append(errorMsg)
                }
                isStreaming = false
                activeToolLabel = nil
                cancelSSEWatchdog()
                finishLatencyTrace(reason: "error")
            }
        }
    }

    /// Start a persistent SSE connection for this session. Call once after loading history.
    func connectSSE() {
        guard sseTask == nil else { return }
        observeTransactionCompletions()
        let userState = buildUserState()
        sseTask = Task {
            while !Task.isCancelled {
                do {
                    for try await response in apiClient.streamUpdates(userState: userState) {
                        if Task.isCancelled { return }
                        processResponse(response, source: "sse")
                        if !response.isProcessing && isStreaming {
                            isStreaming = false
                            activeToolLabel = nil
                            cancelSSEWatchdog()
                            finishLatencyTrace(reason: "completed_sse")
                            await generateTitleIfNeeded()
                        }
                    }
                    // Stream ended normally (server closed it).
                    // If we were mid-stream, fall back to polling to finish.
                    if Task.isCancelled { return }
                    if isStreaming {
                        await pollUntilDone(userState: userState)
                        isStreaming = false
                        activeToolLabel = nil
                        cancelSSEWatchdog()
                        finishLatencyTrace(reason: "completed_poll_after_sse_end")
                        await generateTitleIfNeeded()
                    }
                    // Reconnect after brief delay
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    if Task.isCancelled { return }
                    // SSE error -- if mid-stream, fall back to polling
                    if isStreaming {
                        await pollUntilDone(userState: userState)
                        isStreaming = false
                        activeToolLabel = nil
                        cancelSSEWatchdog()
                        finishLatencyTrace(reason: "completed_poll_after_sse_error")
                        await generateTitleIfNeeded()
                    }
                    // Reconnect with backoff
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }

    /// Disconnect the persistent SSE connection.
    func disconnectSSE() {
        pollTask?.cancel()
        pollTask = nil
        sseTask?.cancel()
        sseTask = nil
        cancelSSEWatchdog()
    }

    func tearDown() {
        disconnectSSE()
        draftSaveTask?.cancel()
        draftSaveTask = nil
        if let txNotificationObserver {
            NotificationCenter.default.removeObserver(txNotificationObserver)
            self.txNotificationObserver = nil
        }
    }

    func interrupt() {
        pollTask?.cancel()
        Task {
            try? await apiClient.interrupt()
            isStreaming = false
            activeToolLabel = nil
            cancelSSEWatchdog()
            finishLatencyTrace(reason: "interrupt")
        }
    }

    func loadHistory() async {
        do {
            // Reset tracking for fresh history load
            apiMessageCount = 0
            renderedAPIMessages.removeAll()
            messages.removeAll()
            cancelSSEWatchdog()
            let response = try await apiClient.getState()
            processResponse(response, source: "history")
        } catch {
            // No history available
        }
    }

    func loadControlPlaneOptions() async {
        do {
            availableModels = try await apiClient.listModels()
        } catch {
            // Control plane may not be available
        }
        do {
            availableNamespaces = try await apiClient.listNamespaces()
        } catch {
            // Control plane may not be available
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

    private func processResponse(_ response: SessionResponse, source: String) {
        let startedAt = Self.now
        markFirstUpdateIfNeeded(source: source, response: response)
        if response.isProcessing {
            lastStreamingUpdateSource = source
            lastStreamingUpdateAt = startedAt
        }

        let apiMessages = response.messages

        if apiMessages.count < apiMessageCount {
            messages.removeSubrange(apiMessages.count..<apiMessageCount)
            apiMessageCount = apiMessages.count
        }

        for (i, apiMsg) in apiMessages.enumerated() {
            if i < renderedAPIMessages.count, renderedAPIMessages[i] == apiMsg {
                continue
            }

            let role: ChatRole = switch apiMsg.sender {
            case .user: .user
            case .agent: .assistant
            case .system: .system
            }
            let newContent = buildContent(from: apiMsg)

            if i < apiMessageCount {
                // Update existing message in-place if content changed
                if messages[i].content != newContent {
                    messages[i].content = newContent
                }
            } else {
                // Insert new API message before any locally-injected messages
                let msg = ChatMessage(role: role, content: newContent)
                messages.insert(msg, at: apiMessageCount)
                apiMessageCount += 1
            }
        }

        renderedAPIMessages = apiMessages

        // Update assistant streaming indicator
        if let last = apiMessages.last, last.sender == .agent, apiMessageCount > 0 {
            currentAssistantMessageId = messages[apiMessageCount - 1].id
        } else if !response.isProcessing {
            currentAssistantMessageId = nil
        }

        // Update streaming label
        if response.isProcessing {
            activeToolLabel = "Processing..."
        } else {
            cancelSSEWatchdog()
        }

        // Update pending transactions from user state, including clearing when empty.
        apiClient.pendingTransactions = response.userState?.pendingTransactions ?? []

        // Process system events for wallet tx requests
        processSystemEvents(response.systemEvents)

        logLatestAgentMessage(source: source, messages: apiMessages, isProcessing: response.isProcessing)
        logProcessResponseDuration(
            source: source,
            startedAt: startedAt,
            messageCount: apiMessages.count,
            isProcessing: response.isProcessing
        )
    }

    private func buildContent(from apiMsg: APIMessage) -> [ChatContent] {
        var content: [ChatContent] = []

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

        return content
    }

    private func processSystemEvents(_ events: [JSONValue]) {
        for event in events {
            // System events have shape: {"InlineCall": {"type": "...", "payload": {...}}}
            guard let inlineCall = event["InlineCall"],
                  let type = inlineCall["type"]?.stringValue,
                  let payload = inlineCall["payload"] else {
                continue
            }

            switch type {
            case "wallet_tx_request":
                handleWalletTxRequest(payload: payload)
            default:
                print("[ChatViewModel] Unknown system event type: \(type)")
            }
        }
    }

    private func handleWalletTxRequest(payload: JSONValue) {
        guard let to = payload["to"]?.stringValue else { return }

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
        guard !processedSystemEventIds.contains(fingerprint) else { return }
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
            chainId: UInt64(selectedNetwork),
            isConnected: walletService.isLoggedIn,
            ensName: apiClient.ensName
        )
    }

    // MARK: - Transaction Lifecycle

    private var txNotificationObserver: Any?

    func observeTransactionCompletions() {
        guard txNotificationObserver == nil else { return }
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

    private func pollUntilDone(userState: APIUserState) async {
        do {
            while !Task.isCancelled {
                try await Task.sleep(for: .milliseconds(500))
                let state = try await apiClient.getState(userState: userState)
                processResponse(state, source: "poll")
                if !state.isProcessing { break }
            }
        } catch {
            if !Task.isCancelled {
                let errorMsg = ChatMessage(role: .system, content: [.error(error.localizedDescription)])
                messages.append(errorMsg)
            }
        }
    }

    private func resumePolling() {
        guard !isStreaming else { return }
        isStreaming = true
        activeToolLabel = "Processing..."
        // Only trust SSE once it has delivered at least one decodable
        // session update on the current connection.
        if !apiClient.isSSEReadyForStreaming {
            pollTask?.cancel()
            pollTask = Task {
                let userState = buildUserState()
                try? await Task.sleep(for: .milliseconds(500))
                await pollUntilDone(userState: userState)
                isStreaming = false
                activeToolLabel = nil
            }
        } else {
            scheduleSSEWatchdog(userState: buildUserState())
        }
    }

    // MARK: - Persistence

    func saveDraft(modelContext: ModelContext) {
        draftSaveTask?.cancel()
        let latestInput = inputText
        draftSaveTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            persistDraft(latestInput, modelContext: modelContext)
        }
    }

    func flushDraftSave(modelContext: ModelContext) {
        draftSaveTask?.cancel()
        persistDraft(inputText, modelContext: modelContext)
    }

    func loadDraft(modelContext: ModelContext) {
        let session = fetchOrCreateDraftSession(modelContext: modelContext)
        inputText = session.draftInputText ?? ""
    }

    func markAssistantTextVisible(messageId: UUID, text: String) {
        guard let currentAssistantMessageId,
              currentAssistantMessageId == messageId,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var trace = activeLatencyTrace,
              !trace.didLogFirstVisibleText else {
            return
        }

        trace.didLogFirstVisibleText = true
        activeLatencyTrace = trace

        let elapsedMs = Self.elapsedMilliseconds(since: trace.startedAt)
        Self.logger.log(
            "[chat-latency] first_visible_text trace=\(trace.id, privacy: .public) session=\(self.sessionId, privacy: .public) elapsed_ms=\(elapsedMs, format: .fixed(precision: 1)) message_id=\(messageId.uuidString, privacy: .public) chars=\(text.count)"
        )
    }

    private func startLatencyTrace(prompt: String) {
        cancelSSEWatchdog()
        let trace = ChatLatencyTrace(
            id: UUID().uuidString,
            startedAt: Self.now,
            promptLength: prompt.count
        )
        activeLatencyTrace = trace
        lastStreamingUpdateSource = nil
        lastStreamingUpdateAt = nil
        Self.logger.log(
            "[chat-latency] request_start trace=\(trace.id, privacy: .public) session=\(self.sessionId, privacy: .public) prompt_chars=\(trace.promptLength)"
        )
    }

    private func markFirstUpdateIfNeeded(source: String, response: SessionResponse) {
        guard var trace = activeLatencyTrace, !trace.didLogFirstUpdate else { return }
        trace.didLogFirstUpdate = true
        activeLatencyTrace = trace

        let elapsedMs = Self.elapsedMilliseconds(since: trace.startedAt)
        Self.logger.log(
            "[chat-latency] first_update trace=\(trace.id, privacy: .public) session=\(self.sessionId, privacy: .public) source=\(source, privacy: .public) elapsed_ms=\(elapsedMs, format: .fixed(precision: 1)) messages=\(response.messages.count) processing=\(response.isProcessing)"
        )
    }

    private func logProcessResponseDuration(source: String, startedAt: TimeInterval, messageCount: Int, isProcessing: Bool) {
        guard let trace = activeLatencyTrace else { return }
        let durationMs = Self.elapsedMilliseconds(since: startedAt)
        Self.logger.log(
            "[chat-latency] process_response trace=\(trace.id, privacy: .public) session=\(self.sessionId, privacy: .public) source=\(source, privacy: .public) duration_ms=\(durationMs, format: .fixed(precision: 1)) messages=\(messageCount) processing=\(isProcessing)"
        )
    }

    private func logLatestAgentMessage(source: String, messages: [APIMessage], isProcessing: Bool) {
        guard let trace = activeLatencyTrace else { return }

        guard let lastAgent = messages.last(where: { $0.sender == .agent }) else {
            Self.logger.log(
                "[chat-latency] latest_agent trace=\(trace.id, privacy: .public) session=\(self.sessionId, privacy: .public) source=\(source, privacy: .public) processing=\(isProcessing) present=false"
            )
            return
        }

        let trimmedContent = lastAgent.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let toolTopic = lastAgent.toolResult?.topic ?? "none"
        let toolChars = lastAgent.toolResult?.content.count ?? 0

        Self.logger.log(
            "[chat-latency] latest_agent trace=\(trace.id, privacy: .public) session=\(self.sessionId, privacy: .public) source=\(source, privacy: .public) processing=\(isProcessing) present=true content_chars=\(trimmedContent.count) streaming=\(lastAgent.isStreaming) tool_topic=\(toolTopic, privacy: .public) tool_chars=\(toolChars)"
        )
    }

    private func finishLatencyTrace(reason: String) {
        guard let trace = activeLatencyTrace else { return }
        let totalMs = Self.elapsedMilliseconds(since: trace.startedAt)
        Self.logger.log(
            "[chat-latency] request_end trace=\(trace.id, privacy: .public) session=\(self.sessionId, privacy: .public) reason=\(reason, privacy: .public) total_ms=\(totalMs, format: .fixed(precision: 1)) first_update_logged=\(trace.didLogFirstUpdate) first_visible_logged=\(trace.didLogFirstVisibleText)"
        )
        activeLatencyTrace = nil
        cancelSSEWatchdog()
    }

    private func scheduleSSEWatchdog(userState: APIUserState) {
        sseWatchdogTask?.cancel()
        let baselineUpdateAt = lastStreamingUpdateAt
        let baselineSource = lastStreamingUpdateSource

        sseWatchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard let self else { return }
            guard !Task.isCancelled,
                  self.isStreaming,
                  self.sseTask != nil,
                  self.lastStreamingUpdateAt == baselineUpdateAt,
                  self.lastStreamingUpdateSource == baselineSource else {
                return
            }

            Self.logger.log(
                "[chat-latency] sse_watchdog_fallback session=\(self.sessionId, privacy: .public) baseline_source=\(baselineSource ?? "none", privacy: .public)"
            )

            do {
                let state = try await self.apiClient.getState(userState: userState)
                self.processResponse(state, source: "watchdog_poll")

                if state.isProcessing {
                    await self.pollUntilDone(userState: userState)
                }

                if self.isStreaming {
                    self.isStreaming = false
                    self.activeToolLabel = nil
                    self.finishLatencyTrace(reason: "completed_watchdog_poll")
                    await self.generateTitleIfNeeded()
                }
            } catch {
                Self.logger.log(
                    "[chat-latency] sse_watchdog_error session=\(self.sessionId, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private func cancelSSEWatchdog() {
        sseWatchdogTask?.cancel()
        sseWatchdogTask = nil
    }

    private func persistDraft(_ text: String, modelContext: ModelContext) {
        let session = fetchOrCreateDraftSession(modelContext: modelContext)
        guard session.draftInputText != text else { return }
        session.draftInputText = text
        try? modelContext.save()
    }

    private func fetchOrCreateDraftSession(modelContext: ModelContext) -> PersistedChatSession {
        if let draftSession {
            return draftSession
        }

        let sid = sessionId
        let descriptor = FetchDescriptor<PersistedChatSession>(
            predicate: #Predicate { $0.sessionId == sid }
        )

        if let session = try? modelContext.fetch(descriptor).first {
            draftSession = session
            return session
        }

        let session = PersistedChatSession(sessionId: sessionId, publicKey: apiClient.publicKey)
        modelContext.insert(session)
        draftSession = session
        try? modelContext.save()
        return session
    }

    private static var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private static func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (now - start) * 1000
    }
}

private struct ChatLatencyTrace {
    let id: String
    let startedAt: TimeInterval
    let promptLength: Int
    var didLogFirstUpdate = false
    var didLogFirstVisibleText = false
}
