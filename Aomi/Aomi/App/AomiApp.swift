import SwiftData
import SwiftUI
import ParaSwift

@main
struct AomiApp: App {
    @State private var apiClient = AomiAPIClient()
    @State private var walletService: ParaWalletService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let apiKey = KeychainService.load(key: "para_api_key") ?? AppConfig.paraAPIKey
        _walletService = State(wrappedValue: ParaWalletService(
            environment: .beta,
            apiKey: apiKey,
            appScheme: AppConfig.paraAppScheme
        ))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else {
                    SessionListView()
                }
            }
            .environment(apiClient)
            .environment(walletService)
            .task {
                // Restore cached address first (sync) so sessions can load immediately
                if let saved = UserDefaults.standard.string(forKey: "activeWalletAddress"), !saved.isEmpty {
                    apiClient.publicKey = saved
                }
                // Then check Para auth (async)
                await walletService.checkAuthStatus()
                if walletService.isLoggedIn {
                    try? await walletService.fetchWallets()
                    // Cache Para wallets to SwiftData
                    if let container = try? ModelContainer(for: PersistedChatSession.self, WalletEntry.self) {
                        let context = ModelContext(container)
                        WalletViewModel.cacheParaWallets(walletService.wallets, modelContext: context)
                        // Update publicKey from Para if it was nil
                        if apiClient.publicKey == nil, let address = walletService.primaryAddress {
                            apiClient.publicKey = address
                            UserDefaults.standard.set(address, forKey: "activeWalletAddress")
                        }
                    }
                } else if apiClient.publicKey == nil {
                    // Fall back to cached Para address from SwiftData
                    if let container = try? ModelContainer(for: PersistedChatSession.self, WalletEntry.self) {
                        let context = ModelContext(container)
                        if let first = WalletViewModel.cachedParaAddresses(modelContext: context).first {
                            apiClient.publicKey = first
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await walletService.checkAuthStatus()
                        if walletService.isLoggedIn {
                            try? await walletService.fetchWallets()
                        }
                    }
                }
            }
        }
        .modelContainer(for: [PersistedChatSession.self, WalletEntry.self])
    }
}
