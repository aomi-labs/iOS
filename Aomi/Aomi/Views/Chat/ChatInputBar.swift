import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onInterrupt: () -> Void
    var isFocused: FocusState<Bool>.Binding

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                TextField("Message aomi...", text: $text, axis: .vertical)
                    .focused(isFocused)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(minHeight: 36)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                if isStreaming {
                    Button {
                        HapticEngine.lightTap()
                        onInterrupt()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .transition(.scale.combined(with: .opacity))
                }

                Button {
                    HapticEngine.messageSent()
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isEmpty ? .gray : Color.accentColor)
                }
                .disabled(isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .animation(.spring(duration: 0.3), value: isStreaming)
    }
}
