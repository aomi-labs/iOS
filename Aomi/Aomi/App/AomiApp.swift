import SwiftData
import SwiftUI
import ParaSwift

@main
struct AomiApp: App {
    @State private var apiClient = AomiAPIClient()
    @State private var walletService: ParaWalletService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
                await walletService.checkAuthStatus()
                if walletService.isLoggedIn {
                    try? await walletService.fetchWallets()
                }
                if let address = walletService.primaryAddress {
                    apiClient.publicKey = address
                }
            }
        }
        .modelContainer(for: [PersistedChatSession.self, WalletEntry.self])
    }
}
