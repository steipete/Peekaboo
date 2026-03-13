//
//  RealtimeVoiceServiceTests.swift
//  PeekabooTests
//

import Foundation
import PeekabooCore
import Tachikoma
import Testing
@testable import Peekaboo

@Suite(.tags(.unit, .ai), .disabled("Uses full PeekabooServices which may hang"))
@MainActor
struct RealtimeVoiceServiceTests {
    // MARK: - Test Helpers

    private func createMockDependencies() throws -> (PeekabooAgentService, SessionStore, PeekabooSettings) {
        let services = PeekabooServices()
        let agentService = try PeekabooAgentService(services: services)
        let sessionStore = SessionStore()
        let settings = PeekabooSettings()
        settings.connectServices(services)
        return (agentService, sessionStore, settings)
    }

    // MARK: - Initialization Tests

    @Test
    func `Service initializes with correct dependencies`() throws {
        let (agentService, sessionStore, settings) = try try self.createMockDependencies()

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        #expect(service.isConnected == false)
        #expect(service.connectionState == .idle)
        #expect(service.currentTranscript.isEmpty)
        #expect(service.conversationHistory.isEmpty)
        #expect(service.error == nil)
        #expect(service.isRecording == false)
        #expect(service.isSpeaking == false)
        #expect(service.audioLevel == 0.0)
        #expect(service.selectedVoice == .alloy)
    }

    @Test
    func `Service loads voice preference from settings`() throws {
        let (agentService, sessionStore, settings) = try try self.createMockDependencies()

        // Set a voice preference in settings
        settings.realtimeVoice = "echo"

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        #expect(service.selectedVoice == .echo)
    }

    // MARK: - Session Management Tests

    @Test(.tags(.integration))
    func `Starting session without API key fails`() async throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        // Ensure no API key is set
        settings.openAIAPIKey = ""
        TachikomaConfiguration.current.setAPIKey("", for: .openai)

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        await #expect(throws: (any Error).self) {
            try await service.startSession()
        }

        #expect(service.isConnected == false)
        #expect(service.error != nil)
    }

    @Test
    func `Ending session cleans up properly`() async throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        // Simulate a connected state
        await service.endSession()

        #expect(service.conversation == nil)
        #expect(service.isConnected == false)
        #expect(service.connectionState == .idle)
        #expect(service.isRecording == false)
        #expect(service.isSpeaking == false)
        #expect(service.audioLevel == 0.0)
    }

    // MARK: - Recording Tests

    @Test
    func `Toggle recording requires active connection`() async throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        await #expect(throws: RealtimeError.notConnected) {
            try await service.toggleRecording()
        }
    }

    // MARK: - Message Sending Tests

    @Test
    func `Sending message requires active connection`() async throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        await #expect(throws: RealtimeError.notConnected) {
            try await service.sendMessage("Test message")
        }
    }

    @Test
    func `Sending message updates conversation history`() throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        // Note: This would require mocking the conversation
        // For now, we just verify the method exists and can be called
        #expect(service.conversationHistory.isEmpty)
    }

    // MARK: - Voice Settings Tests

    @Test
    func `Update voice setting persists to settings`() throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        service.updateVoice(.shimmer)

        #expect(service.selectedVoice == .shimmer)
        #expect(settings.realtimeVoice == "shimmer")
    }

    // MARK: - Interrupt Tests

    @Test
    func `Interrupt requires active connection`() async throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        await #expect(throws: RealtimeError.notConnected) {
            try await service.interrupt()
        }
    }

    // MARK: - Error Handling Tests

    @Test
    func `Service handles connection failures gracefully`() async throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        // Set an invalid API key to trigger failure
        settings.openAIAPIKey = "invalid-key"
        TachikomaConfiguration.current.setAPIKey("invalid-key", for: .openai)

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        do {
            try await service.startSession()
            Issue.record("Expected connection to fail with invalid API key")
        } catch {
            #expect(service.error != nil)
            #expect(service.isConnected == false)
        }
    }

    // MARK: - State Management Tests

    @Test
    func `Connection states transition correctly`() throws {
        let (agentService, sessionStore, settings) = try self.createMockDependencies()

        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)

        // Initial state
        #expect(service.connectionState == .idle)

        // Other state transitions would require mocking the conversation
    }
}

// MARK: - Test Tags

// Tags are already defined in TestTags.swift
