import SwiftUI

struct UserBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Text(message.textContent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)
        }
    }
}
