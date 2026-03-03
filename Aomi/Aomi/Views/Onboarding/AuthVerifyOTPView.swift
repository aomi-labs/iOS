import SwiftUI

struct AuthVerifyOTPView: View {
    let authVM: AuthViewModel
    @Binding var isLoggedIn: Bool
    let inputValue: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    @State private var otpCode = ""
    @State private var isVerifying = false

    // Resend timer
    @State private var resendCountdown: Int = 60
    @State private var canResend = false
    @State private var timer: Timer?

    private let otpLength = 6

    var body: some View {
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
                        Text("Verify your \(inputValue.contains("@") ? "email" : "phone")")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AomiColors.labelPrimary)

                        Text("Enter the code sent to")
                            .font(.system(size: 17))
                            .foregroundColor(AomiColors.labelSecondary)

                        Text(maskedInput)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AomiColors.labelPrimary)
                    }

                    // OTP digit boxes
                    HStack(spacing: 8) {
                        ForEach(0..<otpLength, id: \.self) { index in
                            OTPDigitBox(
                                digit: digit(at: index),
                                isFocused: index == otpCode.count && isInputFocused
                            )
                            .onTapGesture {
                                isInputFocused = true
                            }
                        }
                    }

                    // Error message
                    if !authVM.errorMessage.isEmpty {
                        Text(authVM.errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(AomiColors.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Resend button
                    ResendOTPButton(remainingSeconds: resendCountdown) {
                        handleResend()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Verify button
                VStack(spacing: 16) {
                    Button(action: handleVerify) {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify")
                        }
                    }
                    .buttonStyle(AomiButtonStyle(isEnabled: otpCode.count == otpLength && !isVerifying))
                    .disabled(otpCode.count != otpLength || isVerifying)

                    Text("For testing, use 123456 as the verification code")
                        .font(.system(size: 13))
                        .foregroundColor(AomiColors.labelTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }

            // Hidden text field for keyboard input
            TextField("", text: $otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isInputFocused)
                .opacity(0)
                .onChange(of: otpCode) { _, newValue in
                    // Limit to 6 digits, filter non-digits
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(otpLength))
                    if filtered != newValue {
                        otpCode = filtered
                    }
                    // Auto-verify when 6 digits entered
                    if otpCode.count == otpLength {
                        handleVerify()
                    }
                }
        }
        .navigationBarHidden(true)
        .onAppear {
            isInputFocused = true
            startResendTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Helpers

    private func digit(at index: Int) -> String {
        guard index < otpCode.count else { return "" }
        let digitIndex = otpCode.index(otpCode.startIndex, offsetBy: index)
        return String(otpCode[digitIndex])
    }

    private var maskedInput: String {
        if inputValue.contains("@") {
            let parts = inputValue.split(separator: "@")
            guard parts.count == 2 else { return inputValue }
            let local = String(parts[0])
            let domain = String(parts[1])
            if local.count <= 4 { return inputValue }
            let visible = local.prefix(2)
            let masked = String(repeating: "\u{2022}", count: min(local.count - 4, 6))
            let end = local.suffix(2)
            return "\(visible)\(masked)\(end)@\(domain)"
        } else {
            if inputValue.count <= 4 { return inputValue }
            let masked = String(repeating: "\u{2022}", count: inputValue.count - 4)
            let end = inputValue.suffix(2)
            return "\(inputValue.prefix(2))\(masked)\(end)"
        }
    }

    // MARK: - Timer

    private func startResendTimer() {
        resendCountdown = 60
        canResend = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if resendCountdown > 0 {
                    resendCountdown -= 1
                } else {
                    canResend = true
                    timer?.invalidate()
                }
            }
        }
    }

    // MARK: - Actions

    private func handleVerify() {
        guard otpCode.count == otpLength, !isVerifying else { return }
        isVerifying = true
        isInputFocused = false

        Task {
            let success = await authVM.verifyOTP(code: otpCode)
            if success {
                isLoggedIn = true
            } else {
                otpCode = ""
                isInputFocused = true
            }
            isVerifying = false
        }
    }

    private func handleResend() {
        startResendTimer()
    }
}
