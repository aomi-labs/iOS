import SwiftData
import SwiftUI

@main
struct AomiApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Aomi")
        }
        .modelContainer(for: [PersistedChatSession.self, WalletEntry.self])
    }
}
