import SwiftUI

struct ToolDetailSheet: View {
    let card: ToolUseCard

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: card.iconName)
                        Text(card.toolName)
                            .font(.headline)
                        Spacer()
                        if let elapsed = card.elapsedString {
                            Text(elapsed)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(card.input.prettyString)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Output
                    if let result = card.result {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(result.displayContent)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Tool Details")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
