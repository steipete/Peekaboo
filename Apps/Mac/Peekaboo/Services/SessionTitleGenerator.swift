import Foundation
import PeekabooCore
import Tachikoma

/// Service for generating intelligent session titles using AI
@MainActor
final class SessionTitleGenerator {
    private let configuration = ConfigurationManager.shared

    /// Generate a concise title for a task
    /// - Parameter task: The user's task description
    /// - Returns: A 2-4 word title summarizing the task
    func generateTitle(for task: String) async -> String {
        let providers = self.configuration.getAIProviders()
        let hasOpenAI = self.configuration.getOpenAIAPIKey() != nil
        let hasAnthropic = self.configuration.getAnthropicAPIKey() != nil

        // Use race between timeout and title generation
        return await withTaskGroup(of: String.self) { group in
            // Add timeout task
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    return "New Session"
                } catch {
                    return "New Session"
                }
            }

            // Add generation task
            group.addTask {
                do {
                    // Get the default model from configuration
                    // Determine the model to use
                    let model: LanguageModel = if providers.contains("anthropic"), hasAnthropic {
                        .anthropic(.opus4)
                    } else if providers.contains("openai"), hasOpenAI {
                        .openai(.gpt41)
                    } else if providers.contains("ollama") {
                        .ollama(.llama33)
                    } else {
                        .anthropic(.opus4) // Default fallback
                    }

                    // Create a simple prompt for title generation
                    let prompt = """
                    Generate a 2-4 word title for this task. Be concise and descriptive.
                    Only respond with the title, nothing else.

                    Task: \(task)
                    """

                    // Use the new Tachikoma API
                    let result = try await generateText(
                        model: model,
                        messages: [.user(prompt)],
                        settings: GenerationSettings(
                            maxTokens: 20,
                            temperature: 0.3))

                    let generatedTitle = result.text

                    // Clean up the generated title
                    let cleaned = generatedTitle
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                    // Validate it's reasonable length (2-6 words)
                    let wordCount = cleaned.split(separator: " ").count
                    if wordCount >= 2, wordCount <= 6 {
                        return cleaned
                    } else {
                        return "New Session"
                    }

                } catch {
                    return "New Session"
                }
            }

            // Return the first result (either timeout or generated)
            for await result in group {
                group.cancelAll()
                return result
            }

            return "New Session"
        }
    }

    /// Generate a title from the first user message in a session
    func generateTitleFromFirstMessage(_ message: String) async -> String {
        // Truncate very long messages
        let truncated = String(message.prefix(200))
        return await self.generateTitle(for: truncated)
    }
}
