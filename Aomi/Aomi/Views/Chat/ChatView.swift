import SwiftUI

struct ChatView: View {
    let sessionId: String
    var onTitleGenerated: ((String) -> Void)?
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
        .toolbar {
            if let viewModel {
                ToolbarItem(placement: .topBarTrailing) {
                    controlPlaneButton(viewModel)
                }
            }
        }
        .task(id: sessionId) {
            if let viewModel, viewModel.sessionId == sessionId {
                viewModel.connectSSE()
                await viewModel.loadControlPlaneOptions()
                return
            }

            viewModel?.tearDown()
            let vm = ChatViewModel(
                sessionId: sessionId,
                apiClient: apiClient,
                walletService: walletService
            )
            viewModel = vm
            vm.loadDraft(modelContext: modelContext)
            await vm.loadHistory()
            vm.connectSSE()
            await vm.loadControlPlaneOptions()
        }
        .onDisappear {
            viewModel?.flushDraftSave(modelContext: modelContext)
            viewModel?.tearDown()
        }
        .onChange(of: viewModel?.generatedTitle) { _, newTitle in
            if let newTitle {
                onTitleGenerated?(newTitle)
            }
        }
    }

    @ViewBuilder
    private func chatContent(_ vm: ChatViewModel) -> some View {
        @Bindable var viewModel = vm
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { message in
                        ChatMessageView(
                            message: message,
                            isStreaming: vm.isStreaming && message.id == vm.currentAssistantMessageId,
                            onAssistantTextVisible: vm.markAssistantTextVisible
                        )
                        .id(message.id)
                    }
                    if vm.isStreaming {
                        ThinkingShimmerView(label: vm.activeToolLabel ?? "Thinking...")
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                )
                            )
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
                .animation(.spring(duration: 0.4, bounce: 0.1), value: vm.isStreaming)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollState(for: vm)) { _, _ in
                scrollToBottom(proxy)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatInputBar(
                text: $viewModel.inputText,
                isStreaming: vm.isStreaming,
                onSend: {
                    isInputFocused = false
                    vm.sendMessage()
                },
                onInterrupt: {
                    vm.interrupt()
                },
                isFocused: $isInputFocused
            )
        }
        .onChange(of: vm.inputText) {
            vm.saveDraft(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private func controlPlaneButton(_ vm: ChatViewModel) -> some View {
        NavigationLink {
            ControlPlaneSettingsView(vm: vm)
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(duration: 0.3)) {
            proxy.scrollTo("bottom")
        }
    }

    private func scrollState(for vm: ChatViewModel) -> ScrollState {
        let lastMessage = vm.messages.last
        return ScrollState(
            lastMessageID: lastMessage?.id,
            lastMessageLength: lastMessage?.textContent.count ?? 0,
            isStreaming: vm.isStreaming,
            toolLabel: vm.activeToolLabel
        )
    }
}

private struct ScrollState: Equatable {
    let lastMessageID: UUID?
    let lastMessageLength: Int
    let isStreaming: Bool
    let toolLabel: String?
}
