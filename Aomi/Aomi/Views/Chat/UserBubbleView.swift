import SwiftUI

struct UserBubbleView: View {
    let message: ChatMessage
    @State private var hasAppeared = false

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Text(message.textContent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(.accentColor), in: RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)
                .onAppear {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        hasAppeared = true
                    }
                }
        }
    }
}
