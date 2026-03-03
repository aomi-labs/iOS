import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text("aomi")
                .font(.largeTitle.bold())
            Text("Your AI blockchain assistant")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}
