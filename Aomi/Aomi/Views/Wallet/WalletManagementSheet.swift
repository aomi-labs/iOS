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
            if !walletService.isLoggedIn {
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
                        WalletRowView(address: wallet.address, chain: wallet.chain, label: nil, badge: "signing")
                    }
                }
            }
            if !vm.watchAddresses.isEmpty {
                Section("Watch Only") {
                    ForEach(vm.watchAddresses) { entry in
                        WalletRowView(address: entry.address, chain: entry.chain, label: entry.label, badge: "read-only")
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            vm.removeWatchAddress(vm.watchAddresses[i], modelContext: modelContext)
                        }
                    }
                }
            }
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
