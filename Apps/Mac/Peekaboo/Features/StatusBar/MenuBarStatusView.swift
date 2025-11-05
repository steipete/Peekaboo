import os.log
import PeekabooCore
import SwiftUI
import Tachikoma

struct MenuBarStatusView: View {
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "MenuBarStatus")

    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SpeechRecognizer.self) private var speechRecognizer

    @State private var isHovering = false
    @State private var hasAppeared = false
    @State private var isVoiceMode = false
    @State private var inputText = ""
    @State private var refreshTrigger = UUID()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with current status
            StatusBarHeaderView(isVoiceMode: self.$isVoiceMode)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .modernBackground(style: .toolbar)

            Divider()

            // Main content area - unified experience
            StatusBarContentView()
                .frame(maxHeight: 500)

            Divider()

            // Always show input area and action buttons for consistent experience
            VStack(spacing: 0) {
                // Input area (always visible)
                if self.isVoiceMode {
                    VoiceInputView(onToggleRecording: self.toggleVoiceRecording)
                        .padding(10)
                        .modernBackground(style: .content)
                } else {
                    StatusBarInputView(
                        inputText: self.$inputText,
                        isVoiceMode: self.$isVoiceMode,
                        isInputFocused: self.$isInputFocused,
                        isProcessing: self.agent.isProcessing,
                        onSubmit: self.submitInput)
                        .padding(10)
                        .modernBackground(style: .content)
                }

                Divider()

                // Action buttons (always visible)
                ActionButtonsView()
                    .padding()
                    .modernBackground(style: .toolbar)
            }
        }
        .frame(width: 380)
        .modernBackground(style: .popover)
        .onAppear {
            self.setupViewOnAppear()
        }
        .onChange(of: self.agent.isProcessing) { _, _ in
            self.refreshTrigger = UUID()
        }
        .onChange(of: self.sessionStore.currentSession?.messages.count ?? 0) { _, _ in
            self.refreshTrigger = UUID()
        }
        .onChange(of: self.agent.toolExecutionHistory.count) { _, _ in
            self.refreshTrigger = UUID()
        }
    }

    // MARK: - Setup and Lifecycle

    private func setupViewOnAppear() {
        self.hasAppeared = true
        // Force a UI update in case environment values weren't ready
        DispatchQueue.main.async {
            self.hasAppeared = true
            self.refreshTrigger = UUID()
            // Focus the input field when idle
            if self.sessionStore.currentSession == nil, !self.agent.isProcessing {
                self.isInputFocused = true
            }
        }
    }

    // MARK: - Input Handling

    private func submitInput() {
        let text = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        self.executeTask(text)
        self.inputText = ""
    }

    private func toggleVoiceRecording() {
        if self.speechRecognizer.isListening {
            // Stop and submit
            self.speechRecognizer.stopListening()

            let transcript = self.speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                self.submitVoiceInput(transcript)
            }
        } else {
            // Start listening
            Task {
                do {
                    try self.speechRecognizer.startListening()
                } catch {
                    self.logger.error("Failed to start speech recognition: \(error)")
                }
            }
        }
    }

    private func submitVoiceInput(_ text: String) {
        Task {
            // Close voice mode
            self.isVoiceMode = false
            self.executeTask(text)
        }
    }

    private func executeTask(_ text: String) {
        // Add user message to current session (or create new if needed)
        if let session = sessionStore.currentSession {
            self.sessionStore.addMessage(
                PeekabooCore.ConversationMessage(role: .user, content: text),
                to: session)
        } else {
            // Create new session if needed
            let newSession = self.sessionStore.createSession(title: text)
            self.sessionStore.addMessage(
                PeekabooCore.ConversationMessage(role: .user, content: text),
                to: newSession)
        }

        // Execute the task
        Task {
            do {
                try await self.agent.executeTask(text)
            } catch {
                self.logger.error("Failed to execute task: \(error)")
            }
        }
    }
}
