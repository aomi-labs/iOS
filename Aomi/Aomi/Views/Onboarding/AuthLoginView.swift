import SwiftUI
import AuthenticationServices

struct AuthLoginView: View {
    @Environment(ParaWalletService.self) private var walletService
    @Environment(\.authorizationController) private var authorizationController
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.dismiss) private var dismiss
    @Binding var isLoggedIn: Bool

    @State private var authVM: AuthViewModel?
    @State private var selectedMode: Int = 0
    @State private var emailInput = ""
    @State private var phoneInput = ""
    @State private var selectedCountryCode = "+1"
    @State private var showOTP = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    private let countryCodes = ["+1", "+44", "+81", "+86", "+91", "+49", "+33", "+39", "+34", "+55"]

    var body: some View {
        NavigationStack {
            ZStack {
                AomiColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(AomiColors.labelPrimary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()

                    // Main content
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("Log in or sign up")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AomiColors.labelPrimary)

                            Text("Enter your \(selectedMode == 0 ? "email" : "phone number") to continue")
                                .font(.system(size: 17))
                                .foregroundColor(AomiColors.labelSecondary)
                        }

                        AuthSegmentedControl(
                            selectedIndex: $selectedMode,
                            options: ["Email", "Phone"]
                        )
                        .padding(.horizontal, 60)

                        if selectedMode == 0 {
                            AomiBorderTextField(
                                placeholder: "Email address",
                                text: $emailInput,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )
                        } else {
                            HStack(spacing: 12) {
                                Menu {
                                    ForEach(countryCodes, id: \.self) { code in
                                        Button(code) { selectedCountryCode = code }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(selectedCountryCode)
                                            .font(.system(size: 17))
                                            .foregroundColor(AomiColors.labelPrimary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(AomiColors.labelSecondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(AomiColors.backgroundSecondary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(AomiColors.separator, lineWidth: 1)
                                    )
                                }

                                AomiBorderTextField(
                                    placeholder: "Phone number",
                                    text: $phoneInput,
                                    keyboardType: .phonePad,
                                    textContentType: .telephoneNumber
                                )
                            }
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(AomiColors.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Continue button
                    VStack(spacing: 16) {
                        Button(action: handleContinue) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Continue")
                            }
                        }
                        .buttonStyle(AomiButtonStyle(isEnabled: isValidInput && !isLoading))
                        .disabled(!isValidInput || isLoading)

                        Text("For testing, use <username>@test.getpara.com")
                            .font(.system(size: 13))
                            .foregroundColor(AomiColors.labelTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showOTP) {
                if let authVM {
                    AuthVerifyOTPView(
                        authVM: authVM,
                        isLoggedIn: $isLoggedIn,
                        inputValue: selectedMode == 0 ? emailInput : formattedPhoneNumber
                    )
                }
            }
        }
        .task {
            authVM = AuthViewModel(
                walletService: walletService,
                authorizationController: authorizationController,
                webAuthenticationSession: webAuthenticationSession
            )
        }
    }

    // MARK: - Validation

    private var isValidInput: Bool {
        if selectedMode == 0 {
            return isValidEmail(emailInput)
        } else {
            return phoneInput.count >= 7
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private var formattedPhoneNumber: String {
        "\(selectedCountryCode)\(phoneInput)"
    }

    // MARK: - Actions

    private func handleContinue() {
        guard let authVM else { return }
        HapticEngine.buttonTap()
        isLoading = true
        errorMessage = ""

        let input = selectedMode == 0 ? emailInput : formattedPhoneNumber

        Task {
            await authVM.initiateLogin(input: input)
            if authVM.needsOTPVerification {
                HapticEngine.success()
                showOTP = true
            } else if authVM.errorMessage.isEmpty {
                HapticEngine.success()
                isLoggedIn = true
            } else {
                HapticEngine.error()
                errorMessage = authVM.errorMessage
            }
            isLoading = false
        }
    }
}
