import SwiftUI

struct ActivityFeedView: View {
    @Environment(AomiAPIClient.self) private var apiClient
    @State private var events: [APIEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && events.isEmpty {
                ProgressView()
            } else if let errorMessage, events.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Activity", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") {
                        Task {
                            await loadEvents()
                        }
                    }
                }
            } else if events.isEmpty {
                ContentUnavailableView {
                    Label("No Activity", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Recent events will appear here")
                }
            } else {
                List(events) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(event.type)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(formatTimestamp(event.timestamp))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let summary = eventSummary(event.data) {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .refreshable {
                    await loadEvents()
                }
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadEvents()
        }
    }

    private func loadEvents() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            events = try await apiClient.getEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        // Try ISO 8601 parsing
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        return timestamp
    }

    private func eventSummary(_ data: JSONValue) -> String? {
        if let desc = data["description"]?.stringValue { return desc }
        if let msg = data["message"]?.stringValue { return msg }
        if let title = data["title"]?.stringValue { return title }
        return nil
    }
}
