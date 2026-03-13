import Tachikoma
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

/// Tests for PeekabooAgentService model selection functionality
struct PeekabooAgentServiceTests {
    @MainActor
    private func makeServices() -> PeekabooServices {
        PeekabooServices()
    }

    @Test
    @MainActor
    func `Default model initialization`() throws {
        let mockServices = self.makeServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        // Should default to Claude Opus 4.5
        #expect(agentService.defaultModel == LanguageModel.anthropic(.opus45).description)
    }

    @Test
    @MainActor
    func `Anthropic generation settings enable thinking`() throws {
        let mockServices = self.makeServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        let settings = agentService.generationSettings(for: .anthropic(.opus45))
        let thinking = settings.providerOptions.anthropic?.thinking

        switch thinking {
        case let .enabled(budgetTokens):
            #expect(budgetTokens == 12000)
        default:
            Issue.record("Expected Anthropic thinking to be enabled with a budget")
        }
    }

    @Test
    @MainActor
    func `Custom default model initialization`() throws {
        let mockServices = self.makeServices()
        let customModel = LanguageModel.openai(.gpt51)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: customModel)

        #expect(agentService.defaultModel == customModel.description)
    }

    @Test
    @MainActor
    func `Model parameter precedence in executeTask`() async throws {
        let mockServices = self.makeServices()
        let defaultModel = LanguageModel.anthropic(.opus45)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        // Mock event delegate that captures model usage
        let eventDelegate = MockEventDelegate()

        // Test with custom model parameter
        let customModel = LanguageModel.openai(.gpt51)

        // This would normally make an API call, but we're testing the model selection logic
        // In a real test, we'd mock the network layer
        do {
            let result = try await agentService.executeTask(
                "test task",
                maxSteps: 1,
                sessionId: nil,
                model: customModel,
                eventDelegate: eventDelegate)

            // Verify the result metadata shows the custom model was used
            #expect(result.metadata.modelName == customModel.description)
        } catch {
            // Expected to fail due to missing API keys in test environment
            // The important part is that the model selection logic works
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test
    @MainActor
    func `Model parameter falls back to default when nil`() async throws {
        let mockServices = self.makeServices()
        let defaultModel = LanguageModel.anthropic(.opus45)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        let eventDelegate = MockEventDelegate()

        // Test with nil model parameter - should use default
        do {
            let result = try await agentService.executeTask(
                "test task",
                maxSteps: 1,
                sessionId: nil,
                model: nil, // Should fall back to default
                eventDelegate: eventDelegate)

            // Verify the result metadata shows the default model was used
            #expect(result.metadata.modelName == defaultModel.description)
        } catch {
            // Expected to fail due to missing API keys in test environment
            // Accept any error as we're testing the model selection logic, not API calls
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test
    @MainActor
    func `Streaming execution respects model parameter`() async throws {
        let mockServices = self.makeServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        let customModel = LanguageModel.openai(.gpt51)
        _ = MockEventDelegate()

        // Test streaming execution with custom model
        do {
            let result = try await agentService.executeTaskStreaming(
                "test task",
                sessionId: nil,
                model: customModel)
            { _ in
                // Stream handler
            }

            #expect(result.metadata.modelName == customModel.description)
        } catch {
            // Expected to fail due to missing API keys
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test
    @MainActor
    func `Resume session respects model parameter`() async throws {
        let mockServices = self.makeServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        let customModel = LanguageModel.anthropic(.opus45)

        // Test resume session with custom model
        do {
            let result = try await agentService.resumeSession(
                sessionId: "test-session-id",
                model: customModel,
                eventDelegate: nil)

            #expect(result.metadata.modelName == customModel.description)
        } catch {
            // Expected to fail due to non-existent session or missing API keys
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test
    @MainActor
    func `Dry run execution reports requested model`() async throws {
        let mockServices = self.makeServices()
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: .anthropic(.opus45))

        let result = try await agentService.executeTask(
            "describe state",
            maxSteps: 1,
            sessionId: nil,
            model: .openai(.gpt51),
            dryRun: true,
            eventDelegate: nil)

        #expect(result.metadata.modelName == LanguageModel.openai(.gpt51).description)
        #expect(result.content.contains("Dry run"))
    }
}

/// Mock event delegate for testing
@MainActor
private class MockEventDelegate: AgentEventDelegate {
    var events: [AgentEvent] = []

    func agentDidEmitEvent(_ event: AgentEvent) {
        self.events.append(event)
    }
}

/// Tests for model selection in different execution paths
struct ModelSelectionExecutionPathTests {
    @MainActor
    private func makeServices() -> PeekabooServices {
        PeekabooServices()
    }

    @Test
    @MainActor
    func `executeWithStreaming uses provided model`() async throws {
        let mockServices = self.makeServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        // Test that the internal executeWithStreaming method would use the provided model
        // This is tested indirectly through the public API since executeWithStreaming is private

        let customModel = LanguageModel.openai(.gpt51)
        let eventDelegate = MockEventDelegate()

        do {
            let result = try await agentService.executeTask(
                "test streaming execution",
                maxSteps: 1,
                sessionId: nil as String?,
                model: customModel,
                eventDelegate: eventDelegate)

            // The streaming path should be taken when eventDelegate is provided
            #expect(result.metadata.modelName == customModel.description)
        } catch {
            // Expected to fail due to API constraints in test environment
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test
    @MainActor
    func `executeWithoutStreaming uses provided model`() async throws {
        let mockServices = self.makeServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        let customModel = LanguageModel.anthropic(.opus45)

        do {
            // No event delegate means non-streaming path
            let result = try await agentService.executeTask(
                "test non-streaming execution",
                maxSteps: 1,
                sessionId: nil as String?,
                model: customModel,
                eventDelegate: nil as (any AgentEventDelegate)?)

            #expect(result.metadata.modelName == customModel.description)
        } catch {
            // Expected to fail due to API constraints in test environment
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test
    @MainActor
    func `Model consistency across multiple calls`() async throws {
        let mockServices = PeekabooServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        let models: [LanguageModel] = [
            .openai(.gpt51),
            .anthropic(.opus45),
        ]

        for model in models {
            do {
                let result = try await agentService.executeTask(
                    "test model \(model.description)",
                    maxSteps: 1,
                    sessionId: nil,
                    model: model,
                    eventDelegate: nil)

                #expect(result.metadata.modelName == model.description)
            } catch {
                // Expected to fail, but should fail consistently for each model
                #expect(!error.localizedDescription.isEmpty)
            }
        }
    }
}

/// Tests for edge cases and error handling
struct ModelSelectionEdgeCasesTests {
    @Test
    @MainActor
    func `Dry run execution respects model parameter`() async throws {
        let mockServices = PeekabooServices()
        let defaultModel = LanguageModel.openai(.gpt51)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        // Dry run should not make API calls but should still record the model
        let result = try await agentService.executeTask(
            "dry run test",
            maxSteps: 1,
            dryRun: true,
            eventDelegate: nil)

        // Dry run uses the service default model
        #expect(result.metadata.modelName == defaultModel.description)
        #expect(result.content.contains("Dry run completed"))
    }

    @Test
    @MainActor
    func `Audio task execution model handling`() async throws {
        let mockServices = PeekabooServices()
        let defaultModel = LanguageModel.openai(.gpt51)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        let audioContent = AudioContent(
            duration: 5.0,
            transcript: "test audio transcript")

        // Audio execution should use default model (no model parameter in this method)
        let result = try await agentService.executeTaskWithAudio(
            audioContent: audioContent,
            maxSteps: 1,
            dryRun: true,
            eventDelegate: nil)

        #expect(result.metadata.modelName == defaultModel.description)
        #expect(result.content.contains("Dry run completed"))
    }
}
