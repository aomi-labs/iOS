import SwiftUI

struct AuthVerifyOTPView: View {
    let authVM: AuthViewModel
    @Binding var isLoggedIn: Bool
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter Verification Code")
                .font(.title2.bold())
            Text("Check your email or phone for the code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Code", text: $code)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if !authVM.errorMessage.isEmpty {
                Text(authVM.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    let verified = await authVM.verifyOTP(code: code)
                    if verified {
                        isLoggedIn = true
                    }
                }
            } label: {
                if authVM.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Verify").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(code.count < 4 || authVM.isLoading)
        }
        .padding()
    }
}
