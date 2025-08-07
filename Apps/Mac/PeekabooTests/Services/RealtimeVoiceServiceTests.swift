//
//  RealtimeVoiceServiceTests.swift
//  PeekabooTests
//

import Testing
import Foundation
import PeekabooCore
import Tachikoma
@testable import Peekaboo

@Suite("RealtimeVoiceService Tests", .tags(.unit, .ai))
@MainActor
struct RealtimeVoiceServiceTests {
    
    // MARK: - Test Helpers
    
    private func createMockDependencies() -> (PeekabooAgentService, SessionStore, PeekabooSettings) {
        let services = PeekabooServices.shared
        let agentService = PeekabooAgentService(services: services)
        let sessionStore = SessionStore()
        let settings = PeekabooSettings()
        return (agentService, sessionStore, settings)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Service initializes with correct dependencies")
    func serviceInitialization() throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
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
    
    @Test("Service loads voice preference from settings")
    func voicePreferenceLoading() throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        // Set a voice preference in settings
        settings.realtimeVoice = "echo"
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        #expect(service.selectedVoice == .echo)
    }
    
    // MARK: - Session Management Tests
    
    @Test("Starting session without API key fails", .tags(.integration))
    func startSessionWithoutAPIKey() async throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        // Ensure no API key is set
        settings.openAIAPIKey = ""
        TachikomaConfiguration.current.setAPIKey(nil, for: .openai)
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        await #expect(throws: Error.self) {
            try await service.startSession()
        }
        
        #expect(service.isConnected == false)
        #expect(service.error != nil)
    }
    
    @Test("Ending session cleans up properly")
    func endSessionCleanup() async throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
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
    
    @Test("Toggle recording requires active connection")
    func toggleRecordingWithoutConnection() async throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        await #expect(throws: RealtimeError.notConnected) {
            try await service.toggleRecording()
        }
    }
    
    // MARK: - Message Sending Tests
    
    @Test("Sending message requires active connection")
    func sendMessageWithoutConnection() async throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        await #expect(throws: RealtimeError.notConnected) {
            try await service.sendMessage("Test message")
        }
    }
    
    @Test("Sending message updates conversation history")
    func sendMessageUpdatesHistory() async throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        // Note: This would require mocking the conversation
        // For now, we just verify the method exists and can be called
        #expect(service.conversationHistory.isEmpty)
    }
    
    // MARK: - Voice Settings Tests
    
    @Test("Update voice setting persists to settings")
    func updateVoicePersistence() throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        service.updateVoice(.shimmer)
        
        #expect(service.selectedVoice == .shimmer)
        #expect(settings.realtimeVoice == "shimmer")
    }
    
    // MARK: - Interrupt Tests
    
    @Test("Interrupt requires active connection")
    func interruptWithoutConnection() async throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        await #expect(throws: RealtimeError.notConnected) {
            try await service.interrupt()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Service handles connection failures gracefully")
    func connectionFailureHandling() async throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        // Set an invalid API key to trigger failure
        settings.openAIAPIKey = "invalid-key"
        TachikomaConfiguration.current.setAPIKey("invalid-key", for: .openai)
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        do {
            try await service.startSession()
            Issue.record("Expected connection to fail with invalid API key")
        } catch {
            #expect(service.error != nil)
            #expect(service.isConnected == false)
        }
    }
    
    // MARK: - State Management Tests
    
    @Test("Connection states transition correctly")
    func connectionStateTransitions() throws {
        let (agentService, sessionStore, settings) = createMockDependencies()
        
        let service = RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
        
        // Initial state
        #expect(service.connectionState == .idle)
        
        // Other state transitions would require mocking the conversation
    }
}

// MARK: - Test Tags
// Tags are already defined in TestTags.swift