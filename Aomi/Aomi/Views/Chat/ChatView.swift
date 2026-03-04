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
                            isStreaming: vm.isStreaming && message.id == vm.currentAssistantMessageId
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
            .onChange(of: vm.messages.count) {
                withAnimation(.spring(duration: 0.3)) {
                    proxy.scrollTo("bottom")
                }
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
}
