import MarkdownUI
import SwiftUI

struct AssistantMessageView: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    var onTextVisible: ((UUID, String) -> Void)?
    @State private var selectedToolCard: ToolUseCard?
    @State private var hasAppeared = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(contentRows) { row in
                    switch row.content {
                    case .text(let text):
                        textContent(text)

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
                            .glassEffect(.regular.tint(.red.opacity(0.3)), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Spacer(minLength: 60)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 12)
        .onAppear {
            if !hasAppeared {
                HapticEngine.messageReceived()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    hasAppeared = true
                }
            }
            reportVisibleText(message.textContent)
        }
        .onChange(of: message.textContent) { _, newText in
            reportVisibleText(newText)
        }
        .sheet(item: $selectedToolCard) { card in
            ToolDetailSheet(card: card)
                .onAppear { HapticEngine.sheetPresented() }
        }
    }

    @ViewBuilder
    private func textContent(_ text: String) -> some View {
        Group {
            if isStreaming {
                Text(text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            } else {
                Markdown(text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear { reportVisibleText(text) }
        .onChange(of: text) { _, newText in
            reportVisibleText(newText)
        }
    }

    private func reportVisibleText(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onTextVisible?(message.id, text)
    }

    private var contentRows: [ContentRow] {
        var counts: [String: Int] = [:]
        return message.content.map { content in
            let baseID = content.id
            let occurrence = counts[baseID, default: 0]
            counts[baseID] = occurrence + 1
            return ContentRow(id: "\(baseID)-\(occurrence)", content: content)
        }
    }
}

private struct ContentRow: Identifiable {
    let id: String
    let content: ChatContent
}
