import SwiftUI

struct SessionListView: View {
    @Environment(AomiAPIClient.self) private var apiClient
    @Environment(ParaWalletService.self) private var walletService
    @State private var viewModel: SessionListViewModel?
    @State private var selectedSessionId: String?
    @State private var showWalletSheet = false
    @State private var showActivityFeed = false
    @State private var ensName: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if walletService.wasLoggedOut {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Para session expired. Sign in to send transactions.")
                            .font(.caption)
                        Spacer()
                        Button("Sign In") {
                            showWalletSheet = true
                        }
                        .font(.caption.bold())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }
                Group {
                    if let viewModel {
                        sessionList(viewModel)
                    } else {
                        ProgressView()
                    }
                }
            }
            .navigationTitle("Aomi")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticEngine.lightTap()
                        showWalletSheet = true
                    } label: {
                        if let ensName {
                            Text(ensName)
                                .font(.caption)
                        } else if let address = apiClient.publicKey {
                            Text(truncateAddress(address))
                                .font(.caption.monospaced())
                        } else {
                            Image(systemName: "wallet.bifold")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showActivityFeed = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
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
            }
            .navigationDestination(item: $selectedSessionId) { sessionId in
                ChatView(sessionId: sessionId) { title in
                    viewModel?.updateSessionTitle(id: sessionId, title: title)
                }
            }
            .navigationDestination(isPresented: $showActivityFeed) {
                ActivityFeedView()
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
            await vm.loadSessions()
            await resolveENS()
        }
        .onChange(of: apiClient.publicKey) {
            ensName = nil
            apiClient.ensName = nil
            Task {
                if apiClient.publicKey != nil {
                    await viewModel?.loadSessions()
                }
                await resolveENS()
            }
        }
    }

    @ViewBuilder
    private func sessionList(_ viewModel: SessionListViewModel) -> some View {
        if viewModel.sessions.isEmpty && viewModel.archivedSessions.isEmpty && !viewModel.isLoading {
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteSession(id: session.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                Task { await viewModel.archiveSession(id: session.id) }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                }

                if !viewModel.archivedSessions.isEmpty {
                    Section("Archived") {
                        ForEach(viewModel.archivedSessions) { session in
                            SessionRowView(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticEngine.lightTap()
                                    selectedSessionId = session.id
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteSession(id: session.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        Task { await viewModel.unarchiveSession(id: session.id) }
                                    } label: {
                                        Label("Unarchive", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }
                        }
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

    private func resolveENS() async {
        guard let address = apiClient.publicKey, address.hasPrefix("0x") else { return }
        do {
            let name = try await ENSResolver.shared.reverseLookup(address)
            ensName = name
            apiClient.ensName = name
        } catch {
            // No ENS name for this address
        }
    }
}
