import SwiftUI

struct WidgetRenderer: View {
    let payload: WidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(payload.widgetType, systemImage: "square.grid.2x2")
                .font(.caption.bold())
            Text(payload.data.prettyString)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(5)
        }
        .padding(12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}
