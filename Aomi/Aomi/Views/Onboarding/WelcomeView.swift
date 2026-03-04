import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var hasAppeared = false
    @State private var iconPulse = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.breathe, options: .repeating, value: iconPulse)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1 : 0.7)

            VStack(spacing: 12) {
                Text("aomi")
                    .font(.largeTitle.bold())
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 15)

                Text("Your AI blockchain assistant")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)
            }

            Spacer()

            Button {
                HapticEngine.success()
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
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
        }
        .onAppear {
            iconPulse = true
            withAnimation(.spring(duration: 0.7, bounce: 0.2).delay(0.1)) {
                hasAppeared = true
            }
        }
    }
}
