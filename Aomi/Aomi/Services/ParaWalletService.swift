import Foundation
import SwiftUI
import ParaSwift
import AuthenticationServices

@Observable
@MainActor
final class ParaWalletService {
    let paraManager: ParaManager
    private(set) var isLoggedIn = false
    private(set) var wallets: [Wallet] = []
    private(set) var email: String?

    init(environment: ParaEnvironment = .beta, apiKey: String, appScheme: String) {
        self.paraManager = ParaManager(
            environment: environment,
            apiKey: apiKey,
            appScheme: appScheme
        )
    }

    func checkAuthStatus() async {
        do {
            isLoggedIn = try await paraManager.isFullyLoggedIn()
            if isLoggedIn {
                email = try await paraManager.getEmail()
            }
        } catch {
            isLoggedIn = false
        }
    }

    func initiateAuth(input: String) async throws -> AuthState {
        let auth: Auth = input.contains("@") ? .email(input) : .phone(input)
        return try await paraManager.initiateAuthFlow(auth: auth)
    }

    func handleVerification(code: String) async throws -> AuthState {
        try await paraManager.handleVerificationCode(verificationCode: code)
    }

    func handleSignup(authState: AuthState, authorizationController: AuthorizationController) async throws {
        #if targetEnvironment(simulator)
        try await paraManager.handleSignup(
            authState: authState,
            method: .password,
            authorizationController: authorizationController
        )
        #else
        try await paraManager.handleSignup(
            authState: authState,
            method: .passkey,
            authorizationController: authorizationController
        )
        #endif
    }

    func handleLogin(authState: AuthState, authorizationController: AuthorizationController) async throws {
        #if targetEnvironment(simulator)
        if paraManager.isLoginMethodAvailable(method: .password, authState: authState) {
            try await paraManager.handleLoginWithMethod(
                authState: authState,
                method: .password,
                authorizationController: authorizationController
            )
        }
        #else
        try await paraManager.handleLogin(
            authState: authState,
            authorizationController: authorizationController
        )
        #endif
    }

    func fetchWallets() async throws {
        wallets = try await paraManager.fetchWallets()
    }

    func createWallet(type: WalletType) async throws {
        try await paraManager.createWallet(type: type, skipDistributable: false)
        try await fetchWallets()
    }

    func signMessage(walletId: String, message: String) async throws -> String {
        let result = try await paraManager.signMessage(walletId: walletId, message: message)
        return result.signedTransaction
    }

    var primaryAddress: String? {
        wallets.first(where: { $0.type == .evm })?.address
    }

    func logout() async {
        do {
            try await paraManager.logout()
        } catch {
            // Best-effort logout; clear local state regardless
        }
        isLoggedIn = false
        email = nil
        wallets = []
    }
}
