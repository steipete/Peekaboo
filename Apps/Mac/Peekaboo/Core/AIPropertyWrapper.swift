import Combine
import Foundation
import SwiftUI
import Tachikoma

// MARK: - @AI Property Wrapper for SwiftUI

/// Property wrapper that provides reactive AI model integration for SwiftUI in Peekaboo
@available(macOS 14.0, *)
@propertyWrapper
@MainActor
public struct AI: DynamicProperty {
    @StateObject private var manager: AIManager

    public var wrappedValue: AIManager {
        self.manager
    }

    public var projectedValue: Binding<AIManager> {
        Binding(
            get: { self.manager },
            set: { _ in })
    }

    public init(
        model: Model = .default,
        system: String? = nil,
        settings: GenerationSettings = .default,
        tools: [AgentTool]? = nil)
    {
        // Create AIManager on main actor since it's @MainActor
        let aiManager = AIManager(
            model: model,
            system: system,
            settings: settings,
            tools: tools)
        self._manager = StateObject(wrappedValue: aiManager)
    }
}

// MARK: - AI Manager

/// Observable object that manages AI conversations in SwiftUI for Peekaboo
@available(macOS 14.0, *)
@MainActor
public class AIManager: ObservableObject {
    @Published public var messages: [ModelMessage] = []
    @Published public var isGenerating: Bool = false
    @Published public var error: TachikomaError?
    @Published public var lastResult: String?
    @Published public var streamingText: String = ""

    public let model: Model
    public let system: String?
    public let settings: GenerationSettings
    public let tools: [AgentTool]?

    private var streamingTask: Task<Void, Never>?

    public init(
        model: Model = .default,
        system: String? = nil,
        settings: GenerationSettings = .default,
        tools: [AgentTool]? = nil)
    {
        self.model = model
        self.system = system
        self.settings = settings
        self.tools = tools

        if let system {
            self.messages = [.system(system)]
        }
    }

    // MARK: - Conversation Management

    public func send(_ message: String) async {
        guard !self.isGenerating else { return }

        let userMessage = ModelMessage.user(message)
        self.messages.append(userMessage)

        await self.generateResponse()
    }

    public func send(text: String, images: [ModelMessage.ContentPart.ImageContent]) async {
        guard !self.isGenerating else { return }

        let userMessage = ModelMessage.user(text: text, images: images)
        self.messages.append(userMessage)

        await self.generateResponse()
    }

    public func generateResponse() async {
        guard !self.isGenerating else { return }

        self.isGenerating = true
        self.error = nil
        self.lastResult = nil

        do {
            // Use the proper message-based API instead of extracting text
            let result = try await generateText(
                model: self.model,
                messages: self.messages,
                tools: self.tools,
                settings: self.settings,
                maxSteps: 1)

            self.lastResult = result.text
            self.messages.append(.assistant(result.text))

        } catch let tachikomaError as TachikomaError {
            error = tachikomaError
        } catch {
            self.error = .apiError(error.localizedDescription)
        }

        self.isGenerating = false
    }

    public func streamResponse() async {
        guard !self.isGenerating else { return }

        self.isGenerating = true
        self.error = nil
        self.streamingText = ""

        self.streamingTask = Task {
            do {
                // Use the proper streaming message-based API
                var fullText = ""
                let streamResult = try await streamText(
                    model: self.model,
                    messages: self.messages,
                    tools: self.tools,
                    settings: self.settings,
                    maxSteps: 1)

                for try await delta in streamResult.stream {
                    guard !Task.isCancelled else { break }
                    guard let content = delta.content else { continue }

                    fullText += content
                    await MainActor.run {
                        self.streamingText = fullText
                    }
                }

                await MainActor.run {
                    self.messages.append(.assistant(fullText))
                    self.streamingText = ""
                }

            } catch let tachikomaError as TachikomaError {
                await MainActor.run {
                    error = tachikomaError
                }
            } catch {
                await MainActor.run {
                    self.error = .apiError(error.localizedDescription)
                }
            }

            await MainActor.run {
                self.isGenerating = false
            }
        }
    }

    public func clear() {
        self.messages.removeAll()
        if let system {
            self.messages.append(.system(system))
        }
        self.error = nil
        self.lastResult = nil
        self.streamingText = ""
        self.streamingTask?.cancel()
    }

    public func cancelGeneration() {
        self.streamingTask?.cancel()
        self.isGenerating = false
    }

    // MARK: - Convenience Properties

    public var userMessages: [ModelMessage] {
        self.messages.filter { $0.role == .user }
    }

    public var assistantMessages: [ModelMessage] {
        self.messages.filter { $0.role == .assistant }
    }

    public var conversationMessages: [ModelMessage] {
        self.messages.filter { $0.role == .user || $0.role == .assistant }
    }

    public var hasMessages: Bool {
        !self.conversationMessages.isEmpty
    }

    public var canGenerate: Bool {
        !self.isGenerating && self.hasMessages
    }
}

// MARK: - SwiftUI View Extensions

@available(macOS 14.0, *)
extension View {
    /// Configure AI model for child views
    public func aiModel(_ model: Model) -> some View {
        environment(\.aiModel, model)
    }

    /// Configure AI settings for child views
    public func aiSettings(_ settings: GenerationSettings) -> some View {
        environment(\.aiSettings, settings)
    }

    /// Configure AI tools for child views
    public func aiTools(_ tools: [AgentTool]?) -> some View {
        environment(\.aiTools, tools)
    }
}

// MARK: - Environment Values

@available(macOS 14.0, *)
extension EnvironmentValues {
    public var aiModel: Model {
        get { self[AIModelKey.self] }
        set { self[AIModelKey.self] = newValue }
    }

    public var aiSettings: GenerationSettings {
        get { self[AISettingsKey.self] }
        set { self[AISettingsKey.self] = newValue }
    }

    public var aiTools: [AgentTool]? {
        get { self[AIToolsKey.self] }
        set { self[AIToolsKey.self] = newValue }
    }
}

private struct AIModelKey: EnvironmentKey {
    static let defaultValue: Model = .default
}

private struct AISettingsKey: EnvironmentKey {
    static let defaultValue: GenerationSettings = .default
}

private struct AIToolsKey: EnvironmentKey {
    static let defaultValue: [AgentTool]? = nil
}
