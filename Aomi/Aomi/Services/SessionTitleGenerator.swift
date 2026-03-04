import Foundation
import FoundationModels

@Generable
struct SessionTitle {
    @Guide(description: "A concise 3-6 word title summarizing the conversation topic")
    var title: String
}

@MainActor
final class SessionTitleGenerator {
    private var generatedSessionIds: Set<String> = []

    func generateTitle(
        sessionId: String,
        userMessage: String,
        assistantResponse: String
    ) async -> String? {
        guard !generatedSessionIds.contains(sessionId) else { return nil }
        generatedSessionIds.insert(sessionId)

        let model = SystemLanguageModel.default
        guard model.availability == .available else { return nil }

        let session = LanguageModelSession(instructions: """
            Generate a short, descriptive title (3-6 words) for a conversation. \
            The title should capture the main topic or intent. \
            Do not use quotes or punctuation around the title.
            """)

        let prompt = """
            User message: \(userMessage)
            Assistant response: \(assistantResponse.prefix(500))
            """

        do {
            let response = try await session.respond(to: prompt, generating: SessionTitle.self)
            let title = response.content.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : title
        } catch {
            return nil
        }
    }
}
