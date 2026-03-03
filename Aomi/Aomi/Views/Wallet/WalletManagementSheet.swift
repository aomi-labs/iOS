import SwiftUI
import ParaSwift

struct WalletManagementSheet: View {
    @Environment(ParaWalletService.self) private var walletService
    @Environment(AomiAPIClient.self) private var apiClient
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WalletViewModel?
    @State private var showAddWatch = false
    @State private var showAddPara = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    walletList(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Wallets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Create Para Wallet", systemImage: "plus.circle") {
                            showAddPara = true
                        }
                        Button("Add Watch Address", systemImage: "eye") {
                            showAddWatch = true
                        }
                    } label: {
                        Image(systemName: "plus")
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
                        // Bind wallet to backend
                        Task { try? await apiClient.bindWallet(address: address, platform: "ios", platformUserId: "local") }
                    }
                }
            }
            .alert("Create Wallet", isPresented: $showAddPara) {
                Button("EVM") { createParaWallet(.evm) }
                Button("Solana") { createParaWallet(.solana) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Select blockchain type")
            }
        }
        .task {
            let vm = WalletViewModel(walletService: walletService)
            viewModel = vm
            await vm.loadWallets()
            vm.loadWatchAddresses(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private func walletList(_ vm: WalletViewModel) -> some View {
        List {
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
