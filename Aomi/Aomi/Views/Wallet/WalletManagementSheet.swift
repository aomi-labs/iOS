import SwiftUI
import ParaSwift

struct WalletManagementSheet: View {
    @Environment(ParaWalletService.self) private var walletService
    @Environment(AomiAPIClient.self) private var apiClient
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WalletViewModel?
    @State private var showAddWatch = false
    @State private var showLogin = false
    @State private var hasCheckedWallets = false
    @State private var showLogoutConfirmation = false

    private var hasNoWallets: Bool {
        guard let viewModel else { return false }
        return viewModel.paraWallets.isEmpty && viewModel.watchAddresses.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if hasNoWallets && hasCheckedWallets {
                        addWalletWizard
                    } else {
                        walletList(viewModel)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Wallets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !hasNoWallets || !hasCheckedWallets {
                        Menu {
                            if walletService.isLoggedIn {
                                Button("Create EVM Wallet", systemImage: "plus.circle") {
                                    createParaWallet(.evm)
                                }
                            }
                            Button("Add Watch Address", systemImage: "eye") {
                                showAddWatch = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
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
                        Task { try? await apiClient.bindWallet(address: address, platform: "ios", platformUserId: "local") }
                    }
                }
            }
            .sheet(isPresented: $showLogin) {
                AuthLoginView(isLoggedIn: Binding(
                    get: { walletService.isLoggedIn },
                    set: { newValue in
                        if newValue {
                            showLogin = false
                            Task {
                                try? await walletService.fetchWallets()
                                if let address = walletService.primaryAddress {
                                    apiClient.publicKey = address
                                }
                                await viewModel?.loadWallets()
                            }
                        }
                    }
                ))
            }
        }
        .task {
            let vm = WalletViewModel(walletService: walletService)
            viewModel = vm
            await vm.loadWallets()
            vm.loadWatchAddresses(modelContext: modelContext)
            hasCheckedWallets = true
        }
    }

    @ViewBuilder
    private var addWalletWizard: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "wallet.bifold")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Add a Wallet")
                .font(.title2.bold())
            Text("Connect a Para wallet or add an address to watch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    showLogin = true
                } label: {
                    Label("Sign in with Para", systemImage: "person.crop.circle.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showAddWatch = true
                } label: {
                    Label("Add Watch Address", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func walletList(_ vm: WalletViewModel) -> some View {
        List {
            if walletService.isLoggedIn {
                Section("Account") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(walletService.email ?? "Signed in")
                                .font(.subheadline)
                            Text("Para Wallet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Log Out", role: .destructive) {
                            showLogoutConfirmation = true
                        }
                        .font(.subheadline)
                    }
                }
            } else {
                Section {
                    Button {
                        showLogin = true
                    } label: {
                        Label("Sign in with Para", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
            if !vm.paraWallets.isEmpty {
                Section("Signing Wallets") {
                    ForEach(vm.paraWallets) { wallet in
                        Button {
                            selectWallet(address: wallet.address)
                        } label: {
                            HStack {
                                WalletRowView(address: wallet.address, chain: wallet.chain, label: nil, badge: "signing")
                                if apiClient.publicKey == wallet.address {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            if !vm.watchAddresses.isEmpty {
                Section("Watch Only") {
                    ForEach(vm.watchAddresses) { entry in
                        Button {
                            selectWallet(address: entry.address)
                        } label: {
                            HStack {
                                WalletRowView(address: entry.address, chain: entry.chain, label: entry.label, badge: "read-only")
                                if apiClient.publicKey == entry.address {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            let entry = vm.watchAddresses[i]
                            if apiClient.publicKey == entry.address {
                                apiClient.publicKey = walletService.primaryAddress
                            }
                            vm.removeWatchAddress(entry, modelContext: modelContext)
                        }
                    }
                }
            }

            if !apiClient.pendingTransactions.isEmpty {
                Section("Pending Transactions") {
                    ForEach(apiClient.pendingTransactions) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tx.description)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text("To: \(truncateAddress(tx.to))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(tx.state)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(stateColor(tx.state).opacity(0.15))
                                .foregroundStyle(stateColor(tx.state))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .confirmationDialog("Log out of Para?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                Task {
                    await walletService.logout()
                    apiClient.publicKey = nil
                    UserDefaults.standard.removeObject(forKey: "activeWalletAddress")
                    await vm.loadWallets()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your signing wallets will be removed from this device.")
        }
    }

    private func selectWallet(address: String) {
        HapticEngine.walletSelected()
        apiClient.publicKey = address
        UserDefaults.standard.set(address, forKey: "activeWalletAddress")
    }

    private func truncateAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func stateColor(_ state: String) -> Color {
        switch state.lowercased() {
        case "pending", "submitted": return .orange
        case "confirmed", "success": return .green
        case "failed", "error": return .red
        default: return .secondary
        }
    }

    private func createParaWallet(_ type: ParaSwift.WalletType) {
        Task {
            do {
                try await walletService.createWallet(type: type)
                await viewModel?.loadWallets()
            } catch {}
        }
    }
}
