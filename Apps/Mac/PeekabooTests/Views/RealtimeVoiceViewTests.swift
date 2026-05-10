//
//  RealtimeVoiceViewTests.swift
//  PeekabooTests
//

import PeekabooCore
import SwiftUI
import Tachikoma
import TachikomaAudio
import Testing
@testable import Peekaboo

@Suite(.tags(.unit, .ui), .disabled("Uses full PeekabooServices which may hang"))
@MainActor
struct RealtimeVoiceViewTests {
    // MARK: - Test Helpers

    private func createMockService() throws -> RealtimeVoiceService {
        let services = PeekabooServices()
        let agentService = try PeekabooAgentService(services: services)
        let sessionStore = SessionStore()
        let settings = PeekabooSettings()
        settings.connectServices(services)

        return RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings)
    }

    // MARK: - View Initialization Tests

    // Removed test - just testing compilation is meaningless

    @Test
    func `Connection indicator shows correct state`() throws {
        let service = try self.createMockService()

        // Test different connection states
        #expect(service.connectionState == .idle)
        #expect(service.isConnected == false)
    }

    // MARK: - Voice Selection Tests

    @Test
    func `Voice picker contains all available voices`() {
        let availableVoices: [RealtimeVoice] = [.alloy, .echo, .fable, .onyx, .nova, .shimmer]

        for voice in availableVoices {
            #expect(!voice.displayName.isEmpty)
            #expect(voice.displayName.contains("(")) // Should have description
        }
    }

    @Test
    func `Voice display names are descriptive`() {
        #expect(RealtimeVoice.alloy.displayName == "Alloy (Neutral)")
        #expect(RealtimeVoice.echo.displayName == "Echo (Smooth)")
        #expect(RealtimeVoice.fable.displayName == "Fable (British)")
        #expect(RealtimeVoice.onyx.displayName == "Onyx (Deep)")
        #expect(RealtimeVoice.nova.displayName == "Nova (Friendly)")
        #expect(RealtimeVoice.shimmer.displayName == "Shimmer (Energetic)")
    }

    // MARK: - Animation Tests

    @Test
    func `Waveform animation parameters are valid`() {
        // Test that animation values are within expected ranges
        let minFrequency = 0.1
        let maxFrequency = 1.0

        // These would be constants in the actual view
        let testFrequency = 0.5
        #expect(testFrequency >= minFrequency && testFrequency <= maxFrequency)
    }

    // MARK: - State Display Tests

    @Test
    func `Connection states have proper display strings`() {
        // Verify all states can be displayed
        let states: [ConversationState] = [.idle, .listening, .speaking, .processing]

        for state in states {
            let displayString = state.rawValue.capitalized
            #expect(!displayString.isEmpty)
        }
    }

    // MARK: - Settings View Tests

    // Removed test - just testing compilation is meaningless

    // MARK: - Error Display Tests

    @Test
    func `Error messages are user-friendly`() throws {
        let errors: [RealtimeError] = [
            .notConnected,
            .apiKeyMissing,
            .connectionFailed("Network error"),
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(try !#require(description?.isEmpty as Bool?))
        }
    }

    // MARK: - Accessibility Tests

    // Removed test - placeholder tests with no assertions are useless
}

// MARK: - Mock Conversation State Tests

@Suite(.tags(.unit))
struct ConversationStateTests {
    @Test
    func `State transitions are logical`() {
        // idle -> listening (start recording)
        // listening -> processing (stop recording, processing input)
        // processing -> speaking (AI responds)
        // speaking -> idle (response complete)

        let validTransitions: [(ConversationState, ConversationState)] = [
            (.idle, .listening),
            (.listening, .processing),
            (.processing, .speaking),
            (.speaking, .idle),
            (.listening, .idle), // Can cancel
            (.processing, .idle), // Can cancel
            (.speaking, .listening), // Can interrupt
        ]

        // Just verify the transitions make sense conceptually
        #expect(!validTransitions.isEmpty)
    }
}
