import SwiftUI

struct SessionRowView: View {
    let session: SessionItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle)
                    .font(.body)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
