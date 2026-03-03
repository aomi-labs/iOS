import SwiftUI
import ParaSwift
import AuthenticationServices

@Observable
@MainActor
final class AuthViewModel {
    var errorMessage = ""
    var isLoading = false
    var needsOTPVerification = false
    var authState: AuthState?

    private let walletService: ParaWalletService

    init(walletService: ParaWalletService) {
        self.walletService = walletService
    }

    func initiateLogin(input: String) async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            let state = try await walletService.initiateAuth(input: input)
            switch state.stage {
            case .login, .done:
                authState = state
            case .verify, .signup:
                authState = state
                needsOTPVerification = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyOTP(code: String) async -> Bool {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            let verifiedState = try await walletService.handleVerification(code: code)
            authState = verifiedState
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func completeAuth(authorizationController: AuthorizationController) async -> Bool {
        guard let authState else { return false }
        isLoading = true
        defer { isLoading = false }

        do {
            switch authState.stage {
            case .signup:
                try await walletService.handleSignup(
                    authState: authState,
                    authorizationController: authorizationController
                )
            case .login:
                try await walletService.handleLogin(
                    authState: authState,
                    authorizationController: authorizationController
                )
            case .done:
                break
            case .verify:
                errorMessage = "Unexpected state"
                return false
            }

            try await walletService.fetchWallets()
            if walletService.wallets.isEmpty {
                try await walletService.createWallet(type: .evm)
            }
            await walletService.checkAuthStatus()
            return walletService.isLoggedIn
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
