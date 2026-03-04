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
                        HapticEngine.lightTap()
                        showWalletSheet = true
                    } label: {
                        if let address = apiClient.publicKey {
                            Text(truncateAddress(address))
                                .font(.caption.monospaced())
                        } else {
                            Image(systemName: "wallet.bifold")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticEngine.sessionCreated()
                        guard let viewModel else { return }
                        let id = viewModel.createNewSession()
                        selectedSessionId = id
                    } label: {
                        Image(systemName: "plus.message")
                    }
                }
            }
            .navigationDestination(item: $selectedSessionId) { sessionId in
                ChatView(sessionId: sessionId) { title in
                    viewModel?.updateSessionTitle(id: sessionId, title: title)
                }
            }
            .sheet(isPresented: $showWalletSheet, onDismiss: {
                Task { await viewModel?.loadSessions() }
            }) {
                WalletManagementSheet()
                    .onAppear { HapticEngine.sheetPresented() }
            }
        }
        .task {
            let vm = SessionListViewModel(apiClient: apiClient)
            viewModel = vm
            // Wait for publicKey to be restored before fetching sessions
            // (AomiApp.task restores wallet state concurrently)
            for _ in 0..<20 {
                if apiClient.publicKey != nil { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
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
                            HapticEngine.lightTap()
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
