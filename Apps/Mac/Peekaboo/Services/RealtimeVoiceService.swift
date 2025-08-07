//
//  RealtimeVoiceService.swift
//  Peekaboo
//

import Foundation
import PeekabooCore
import Tachikoma
import os.log

/// Service for managing OpenAI Realtime API voice conversations
@available(macOS 14.0, *)
@Observable
@MainActor
final class RealtimeVoiceService {
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "RealtimeVoice")
    
    // MARK: - Observable State
    
    /// The active realtime conversation
    private(set) var conversation: RealtimeConversation?
    
    /// Whether we're connected to the Realtime API
    private(set) var isConnected = false
    
    /// Current conversation state
    private(set) var connectionState: ConversationState = .idle
    
    /// Live transcript of the conversation
    private(set) var currentTranscript = ""
    
    /// Full conversation history
    private(set) var conversationHistory: [String] = []
    
    /// Current error if any
    private(set) var error: Error?
    
    /// Whether audio is currently being recorded
    private(set) var isRecording = false
    
    /// Whether the assistant is currently speaking
    private(set) var isSpeaking = false
    
    /// Audio level for visual feedback (0.0 to 1.0)
    private(set) var audioLevel: Float = 0.0
    
    /// Selected voice for the assistant
    var selectedVoice: RealtimeVoice = .alloy
    
    /// Custom instructions for the assistant
    var customInstructions: String?
    
    // MARK: - Dependencies
    
    private let agentService: PeekabooAgentService
    private let sessionStore: SessionStore
    private let settings: PeekabooSettings
    
    // MARK: - Private Properties
    
    private var monitoringTasks: Set<Task<Void, Never>> = []
    private var currentSessionId: String?
    
    // MARK: - Initialization
    
    init(
        agentService: PeekabooAgentService,
        sessionStore: SessionStore,
        settings: PeekabooSettings
    ) {
        self.agentService = agentService
        self.sessionStore = sessionStore
        self.settings = settings
        
        // Load voice preference from settings if available
        if let savedVoice = settings.realtimeVoice,
           let voice = RealtimeVoice(rawValue: savedVoice) {
            self.selectedVoice = voice
        }
    }
    
    // MARK: - Public Methods
    
    /// Start a new realtime voice session
    func startSession() async throws {
        logger.info("Starting realtime voice session")
        
        // Clean up any existing session
        if isConnected {
            await endSession()
        }
        
        // Reset state
        error = nil
        currentTranscript = ""
        conversationHistory = []
        
        // Create agent tools from PeekabooCore
        let tools = agentService.createAgentTools()
        logger.debug("Registered \(tools.count) tools for realtime session")
        
        // Prepare instructions
        let instructions = customInstructions ?? """
            You are Peekaboo, a helpful voice assistant for macOS automation.
            You can control applications, interact with UI elements, and help users with their tasks.
            Keep responses concise and conversational.
            When using tools, briefly explain what you're doing.
            """
        
        do {
            // Start realtime conversation using Tachikoma
            conversation = try await startRealtimeConversation(
                model: .gpt4oRealtime,
                voice: selectedVoice,
                instructions: instructions,
                tools: tools,
                configuration: TachikomaConfiguration.current
            )
            
            isConnected = true
            connectionState = .idle
            
            // Create a new session in the store
            currentSessionId = UUID().uuidString
            let session = sessionStore.createSession(title: "Voice Conversation")
            currentSessionId = session.id
            
            // Start monitoring conversation events
            await startMonitoring()
            
            logger.info("Realtime voice session started successfully")
        } catch {
            self.error = error
            logger.error("Failed to start realtime session: \(error)")
            throw error
        }
    }
    
    /// End the current realtime session
    func endSession() async {
        logger.info("Ending realtime voice session")
        
        // Cancel monitoring tasks
        for task in monitoringTasks {
            task.cancel()
        }
        monitoringTasks.removeAll()
        
        // End the conversation
        if let conversation {
            await conversation.end()
        }
        
        // Update state
        conversation = nil
        isConnected = false
        connectionState = .idle
        isRecording = false
        isSpeaking = false
        audioLevel = 0.0
        
        // Save final session state if needed
        if let sessionId = currentSessionId,
           let session = sessionStore.sessions.first(where: { $0.id == sessionId }) {
            // Add final transcript to session
            if !currentTranscript.isEmpty {
                sessionStore.addMessage(
                    ConversationMessage(role: .assistant, content: currentTranscript),
                    to: session
                )
            }
        }
        
        currentSessionId = nil
        logger.info("Realtime voice session ended")
    }
    
    /// Toggle recording (push to talk style)
    func toggleRecording() async throws {
        guard let conversation else {
            throw RealtimeError.notConnected
        }
        
        if isRecording {
            await conversation.stopListening()
            isRecording = false
        } else {
            try await conversation.startListening()
            isRecording = true
        }
    }
    
    /// Send a text message to the conversation
    func sendMessage(_ text: String) async throws {
        guard let conversation else {
            throw RealtimeError.notConnected
        }
        
        // Add to conversation history
        conversationHistory.append("User: \(text)")
        
        // Send to API
        try await conversation.sendText(text)
        
        // Add to session store
        if let sessionId = currentSessionId,
           let session = sessionStore.sessions.first(where: { $0.id == sessionId }) {
            sessionStore.addMessage(
                ConversationMessage(role: .user, content: text),
                to: session
            )
        }
    }
    
    /// Interrupt the current response
    func interrupt() async throws {
        guard let conversation else {
            throw RealtimeError.notConnected
        }
        
        try await conversation.interrupt()
    }
    
    /// Update the voice setting
    func updateVoice(_ voice: RealtimeVoice) {
        selectedVoice = voice
        settings.realtimeVoice = voice.rawValue
        
        // Note: Voice changes will take effect on the next session
        // OpenAI doesn't allow changing voice mid-session
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() async {
        guard let conversation else { return }
        
        // Monitor transcript updates
        let transcriptTask = Task {
            for await text in conversation.transcriptUpdates {
                await MainActor.run {
                    self.currentTranscript = text
                    self.conversationHistory.append("Assistant: \(text)")
                    
                    // Add to session store
                    if let sessionId = self.currentSessionId,
                       let session = self.sessionStore.sessions.first(where: { $0.id == sessionId }) {
                        self.sessionStore.addMessage(
                            ConversationMessage(role: .assistant, content: text),
                            to: session
                        )
                    }
                }
            }
        }
        monitoringTasks.insert(transcriptTask)
        
        // Monitor state changes
        let stateTask = Task {
            for await state in conversation.stateChanges {
                await MainActor.run {
                    self.connectionState = state
                    
                    // Update recording/speaking flags based on state
                    switch state {
                    case .listening:
                        self.isRecording = true
                        self.isSpeaking = false
                    case .speaking:
                        self.isRecording = false
                        self.isSpeaking = true
                    case .idle:
                        self.isRecording = false
                        self.isSpeaking = false
                    default:
                        break
                    }
                }
            }
        }
        monitoringTasks.insert(stateTask)
        
        // Monitor audio levels
        let audioTask = Task {
            for await level in conversation.audioLevelUpdates {
                await MainActor.run {
                    self.audioLevel = level
                }
            }
        }
        monitoringTasks.insert(audioTask)
    }
}

// MARK: - Error Types

enum RealtimeError: LocalizedError {
    case notConnected
    case apiKeyMissing
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Realtime API"
        case .apiKeyMissing:
            return "OpenAI API key is required for Realtime API"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}

// MARK: - Settings Extension

// Note: @AppStorage properties need to be added directly to PeekabooSettings class,
// not in an extension, as Swift doesn't allow stored properties in extensions.
// These properties should be added to the main PeekabooSettings class.