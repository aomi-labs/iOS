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
