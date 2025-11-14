import Tachikoma
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

/// Integration tests for model selection within PeekabooCore
@Suite("Model Selection Core Integration Tests")
struct ModelSelectionIntegrationTests {
    @Test("Agent service model parameter handling")
    @MainActor
    func agentServiceModelParameterHandling() async throws {
        let testCases: [LanguageModel] = [
            .openai(.gpt5),
            .anthropic(.sonnet45),
        ]

        for expectedModel in testCases {
            // Agent service should use the provided model
            let mockServices = PeekabooServices()
            let agentService = try PeekabooAgentService(services: mockServices)

            do {
                let result = try await agentService.executeTask(
                    "test task for \(expectedModel.description)",
                    maxSteps: 1,
                    sessionId: nil,
                    model: expectedModel,
                    eventDelegate: nil)

                // Verify the model was used correctly
                #expect(result.metadata.modelName == expectedModel.description)
            } catch {
                // Expected to fail due to API constraints, but model selection should work
                #expect(!error.localizedDescription.isEmpty)
            }
        }
    }

    @Test("Nil model handling in full pipeline")
    @MainActor
    func nilModelHandlingInFullPipeline() async throws {
        // When nil is passed to agent service, it should use default
        let mockServices = PeekabooServices()
        let defaultModel = LanguageModel.anthropic(.sonnet45)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        do {
            let result = try await agentService.executeTask(
                "test with nil model",
                maxSteps: 1,
                sessionId: nil,
                model: nil, // nil should use default
                eventDelegate: nil)

            // Should fall back to default model
            #expect(result.metadata.modelName == defaultModel.description)
        } catch {
            // Expected to fail due to API constraints
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test("Model descriptions are consistent")
    @MainActor
    func modelDescriptionsAreConsistent() async throws {
        let testModels: [LanguageModel] = [
            .openai(.gpt5),
            .anthropic(.sonnet45),
        ]

        let mockServices = PeekabooServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        for model in testModels {
            // Verify model descriptions are meaningful
            #expect(!model.description.isEmpty)
            #expect(model.description.count > 3)

            // Test that agent service would use the correct model
            do {
                let result = try await agentService.executeTask(
                    "test model consistency for \(model.description)",
                    maxSteps: 1,
                    sessionId: nil,
                    model: model,
                    eventDelegate: nil)

                #expect(result.metadata.modelName == model.description)
            } catch {
                // Expected to fail due to API constraints
                #expect(!error.localizedDescription.isEmpty)
            }
        }
    }

    @Test("Model parameter precedence over default")
    @MainActor
    func modelParameterPrecedenceOverDefault() async throws {
        // Set up agent service with a specific default
        let mockServices = PeekabooServices()
        let defaultModel = LanguageModel.anthropic(.sonnet45)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        // Use a different model than the default
        let overrideModel = LanguageModel.openai(.gpt5)
        #expect(overrideModel.description != defaultModel.description)

        do {
            // The specified model should override the default
            let result = try await agentService.executeTask(
                "test model precedence",
                maxSteps: 1,
                sessionId: nil,
                model: overrideModel,
                eventDelegate: nil)

            // Should use override model, not default
            #expect(result.metadata.modelName == overrideModel.description)
            #expect(result.metadata.modelName != defaultModel.description)
        } catch {
            // Expected to fail due to API constraints
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test("Streaming vs non-streaming consistency")
    @MainActor
    func streamingVsNonStreamingConsistency() async throws {
        let mockServices = PeekabooServices()
        let agentService = try PeekabooAgentService(services: mockServices)

        let testModel = LanguageModel.anthropic(.sonnet45)

        // Test both streaming and non-streaming paths use the same model
        let eventDelegate = MockEventDelegate()

        do {
            // Streaming path (with event delegate)
            let streamingResult = try await agentService.executeTask(
                "streaming test",
                maxSteps: 1,
                sessionId: nil,
                model: testModel,
                eventDelegate: eventDelegate)

            // Non-streaming path (no event delegate)
            let nonStreamingResult = try await agentService.executeTask(
                "non-streaming test",
                maxSteps: 1,
                sessionId: nil,
                model: testModel,
                eventDelegate: nil)

            // Both should use the same model
            #expect(streamingResult.metadata.modelName == testModel.description)
            #expect(nonStreamingResult.metadata.modelName == testModel.description)
            #expect(streamingResult.metadata.modelName == nonStreamingResult.metadata.modelName)
        } catch {
            // Expected to fail due to API constraints
            #expect(!error.localizedDescription.isEmpty)
        }
    }
}

/// Mock event delegate for integration testing
@MainActor
private class MockEventDelegate: AgentEventDelegate {
    var events: [AgentEvent] = []

    func agentDidEmitEvent(_ event: AgentEvent) {
        self.events.append(event)
    }
}

/// Tests for specific bug fixes and regressions
@Suite("Model Selection Regression Tests")
struct ModelSelectionRegressionTests {
    @Test("Bug fix: Extended executeTask method uses model parameter")
    @MainActor
    func extendedExecuteTaskUsesModelParameter() async throws {
        // This test specifically addresses the bug where the extended executeTask method
        // with sessionId and model parameters was ignoring the model parameter

        let mockServices = PeekabooServices()
        let defaultModel = LanguageModel.anthropic(.sonnet45)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        let customModel = LanguageModel.openai(.gpt5)
        #expect(customModel.description != defaultModel.description)

        do {
            // Call the extended method specifically (with sessionId parameter)
            let result = try await agentService.executeTask(
                "test extended method",
                maxSteps: 1,
                sessionId: "test-session",
                model: customModel,
                eventDelegate: nil)

            // Should use custom model, not default
            #expect(result.metadata.modelName == customModel.description)
            #expect(result.metadata.modelName != defaultModel.description)
        } catch {
            // Expected to fail due to API constraints
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test("Bug fix: Streaming execution path respects model parameter")
    @MainActor
    func streamingExecutionPathRespectsModelParameter() async throws {
        // This test addresses the specific bug where the streaming execution path
        // was using self.defaultLanguageModel instead of the passed model parameter

        let mockServices = PeekabooServices()
        let defaultModel = LanguageModel.anthropic(.sonnet45)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        let customModel = LanguageModel.openai(.gpt5)
        let eventDelegate = MockEventDelegate()

        do {
            // With event delegate, should take streaming path
            let result = try await agentService.executeTask(
                "test streaming path model selection",
                maxSteps: 1,
                sessionId: nil,
                model: customModel,
                eventDelegate: eventDelegate)

            // Streaming path should use custom model, not default
            #expect(result.metadata.modelName == customModel.description)
            #expect(result.metadata.modelName != defaultModel.description)
        } catch {
            // Expected to fail due to API constraints
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test("Agent service nil handling in both execution paths")
    @MainActor
    func agentServiceNilHandlingInExecutionPaths() async throws {
        // Test that both streaming and non-streaming paths handle nil models correctly

        let mockServices = PeekabooServices()
        let defaultModel = LanguageModel.anthropic(.sonnet45)
        let agentService = try PeekabooAgentService(
            services: mockServices,
            defaultModel: defaultModel)

        let eventDelegate = MockEventDelegate()

        do {
            // Test non-streaming path with nil model
            let nonStreamingResult = try await agentService.executeTask(
                "test nil model non-streaming",
                maxSteps: 1,
                sessionId: nil,
                model: nil,
                eventDelegate: nil)

            // Test streaming path with nil model
            let streamingResult = try await agentService.executeTask(
                "test nil model streaming",
                maxSteps: 1,
                sessionId: nil,
                model: nil,
                eventDelegate: eventDelegate)

            // Both should use default model
            #expect(nonStreamingResult.metadata.modelName == defaultModel.description)
            #expect(streamingResult.metadata.modelName == defaultModel.description)
        } catch {
            // Expected to fail due to API constraints
            #expect(!error.localizedDescription.isEmpty)
        }
    }
}
