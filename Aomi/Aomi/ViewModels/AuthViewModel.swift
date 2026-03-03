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
    private let authorizationController: AuthorizationController
    private let webAuthenticationSession: WebAuthenticationSession

    init(walletService: ParaWalletService,
         authorizationController: AuthorizationController,
         webAuthenticationSession: WebAuthenticationSession) {
        self.walletService = walletService
        self.authorizationController = authorizationController
        self.webAuthenticationSession = webAuthenticationSession

        // Set default web auth session on ParaManager - needed for hosted OTP webview flow
        walletService.paraManager.setDefaultWebAuthenticationSession(webAuthenticationSession)
    }

    func initiateLogin(input: String) async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            let state = try await walletService.initiateAuth(input: input)
            switch state.stage {
            case .login, .done:
                // Existing user - complete auth immediately
                authState = state
                try await walletService.completeAuth(
                    authState: state,
                    authorizationController: authorizationController,
                    webAuthenticationSession: webAuthenticationSession
                )
            case .verify, .signup:
                // New user or needs OTP
                authState = state
                needsOTPVerification = true
            }
        } catch {
            print("[AuthVM] initiateLogin error: \(error)")
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

            // Complete authentication (signup/login + wallet creation)
            try await walletService.completeAuth(
                authState: verifiedState,
                authorizationController: authorizationController,
                webAuthenticationSession: webAuthenticationSession
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
