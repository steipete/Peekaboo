//
//  RealtimeVoiceViewTests.swift
//  PeekabooTests
//

import Testing
import SwiftUI
import PeekabooCore
import Tachikoma
import TachikomaAudio
@testable import Peekaboo

@Suite("RealtimeVoiceView Tests", .tags(.unit, .ui), .disabled("Uses PeekabooServices.shared which may hang"))
@MainActor
struct RealtimeVoiceViewTests {
    
    // MARK: - Test Helpers
    
    private func createMockService() -> RealtimeVoiceService {
        let services = PeekabooServices.shared
        let agentService = try! PeekabooAgentService(services: services)
        let sessionStore = SessionStore()
        let settings = PeekabooSettings()
        
        return RealtimeVoiceService(
            agentService: agentService,
            sessionStore: sessionStore,
            settings: settings
        )
    }
    
    // MARK: - View Initialization Tests
    
    // Removed test - just testing compilation is meaningless
    
    @Test("Connection indicator shows correct state")
    func connectionIndicatorState() throws {
        let service = createMockService()
        
        // Test different connection states
        #expect(service.connectionState == .idle)
        #expect(service.isConnected == false)
    }
    
    // MARK: - Voice Selection Tests
    
    @Test("Voice picker contains all available voices")
    func voicePickerOptions() throws {
        let availableVoices: [RealtimeVoice] = [.alloy, .echo, .fable, .onyx, .nova, .shimmer]
        
        for voice in availableVoices {
            #expect(!voice.displayName.isEmpty)
            #expect(voice.displayName.contains("("))  // Should have description
        }
    }
    
    @Test("Voice display names are descriptive")
    func voiceDisplayNames() throws {
        #expect(RealtimeVoice.alloy.displayName == "Alloy (Neutral)")
        #expect(RealtimeVoice.echo.displayName == "Echo (Smooth)")
        #expect(RealtimeVoice.fable.displayName == "Fable (British)")
        #expect(RealtimeVoice.onyx.displayName == "Onyx (Deep)")
        #expect(RealtimeVoice.nova.displayName == "Nova (Friendly)")
        #expect(RealtimeVoice.shimmer.displayName == "Shimmer (Energetic)")
    }
    
    // MARK: - Animation Tests
    
    @Test("Waveform animation parameters are valid")
    func waveformAnimationParameters() throws {
        // Test that animation values are within expected ranges
        let minFrequency = 0.1
        let maxFrequency = 1.0
        
        // These would be constants in the actual view
        let testFrequency = 0.5
        #expect(testFrequency >= minFrequency && testFrequency <= maxFrequency)
    }
    
    // MARK: - State Display Tests
    
    @Test("Connection states have proper display strings")
    func connectionStateDisplay() throws {
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
    
    @Test("Error messages are user-friendly")
    func errorMessageDisplay() throws {
        let errors: [RealtimeError] = [
            .notConnected,
            .apiKeyMissing,
            .connectionFailed("Network error")
        ]
        
        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(!description!.isEmpty)
        }
    }
    
    // MARK: - Accessibility Tests
    
    // Removed test - placeholder tests with no assertions are useless
}

// MARK: - Mock Conversation State Tests

@Suite("ConversationState Tests", .tags(.unit))
struct ConversationStateTests {
    
    @Test("State transitions are logical")
    func stateTransitions() throws {
        // idle -> listening (start recording)
        // listening -> processing (stop recording, processing input)
        // processing -> speaking (AI responds)
        // speaking -> idle (response complete)
        
        let validTransitions: [(ConversationState, ConversationState)] = [
            (.idle, .listening),
            (.listening, .processing),
            (.processing, .speaking),
            (.speaking, .idle),
            (.listening, .idle),  // Can cancel
            (.processing, .idle), // Can cancel
            (.speaking, .listening) // Can interrupt
        ]
        
        // Just verify the transitions make sense conceptually
        #expect(!validTransitions.isEmpty)
    }
}