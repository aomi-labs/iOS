import MarkdownUI
import SwiftUI

struct AssistantMessageView: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    @State private var selectedToolCard: ToolUseCard?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(message.content) { contentBlock in
                    switch contentBlock {
                    case .text(let text):
                        Markdown(text)
                            .textSelection(.enabled)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16))

                    case .toolUse(let card):
                        if card.result != nil {
                            ToolStepRow(card: card) { selectedToolCard = card }
                        }

                    case .toolResult:
                        EmptyView()

                    case .widget(let payload):
                        WidgetRenderer(payload: payload)

                    case .error(let errorMessage):
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Spacer(minLength: 60)
        }
        .sheet(item: $selectedToolCard) { card in
            ToolDetailSheet(card: card)
        }
    }
}
