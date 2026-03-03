import SwiftUI
import AuthenticationServices

struct AuthLoginView: View {
    @Environment(ParaWalletService.self) private var walletService
    @State private var authVM: AuthViewModel?
    @State private var input = ""
    @State private var showOTP = false
    @Binding var isLoggedIn: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Connect with Para")
                    .font(.title2.bold())
                Text("Enter your email or phone to create or access your embedded wallet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Email or phone", text: $input)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if let authVM, !authVM.errorMessage.isEmpty {
                    Text(authVM.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    guard let authVM else { return }
                    Task {
                        await authVM.initiateLogin(input: input)
                        if authVM.needsOTPVerification {
                            showOTP = true
                        }
                    }
                } label: {
                    if authVM?.isLoading == true {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(input.isEmpty || authVM?.isLoading == true)
            }
            .padding()
            .navigationDestination(isPresented: $showOTP) {
                if let authVM {
                    AuthVerifyOTPView(authVM: authVM, isLoggedIn: $isLoggedIn)
                }
            }
        }
        .task {
            authVM = AuthViewModel(walletService: walletService)
        }
    }
}
