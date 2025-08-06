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
            StatusBarHeaderView(isVoiceMode: $isVoiceMode)
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
                if isVoiceMode {
                    VoiceInputView(onToggleRecording: toggleVoiceRecording)
                        .padding(10)
                        .modernBackground(style: .content)
                } else {
                    StatusBarInputView(
                        inputText: $inputText,
                        isVoiceMode: $isVoiceMode,
                        isInputFocused: $isInputFocused,
                        isProcessing: agent.isProcessing,
                        onSubmit: submitInput
                    )
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
            setupViewOnAppear()
        }
        .onChange(of: agent.isProcessing) { _, _ in
            refreshTrigger = UUID()
        }
        .onChange(of: sessionStore.currentSession?.messages.count ?? 0) { _, _ in
            refreshTrigger = UUID()
        }
        .onChange(of: agent.toolExecutionHistory.count) { _, _ in
            refreshTrigger = UUID()
        }
    }

    // MARK: - Setup and Lifecycle

    private func setupViewOnAppear() {
        hasAppeared = true
        // Force a UI update in case environment values weren't ready
        DispatchQueue.main.async {
            hasAppeared = true
            refreshTrigger = UUID()
            // Focus the input field when idle
            if sessionStore.currentSession == nil && !agent.isProcessing {
                isInputFocused = true
            }
        }
    }

    // MARK: - Input Handling

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        executeTask(text)
        inputText = ""
    }

    private func toggleVoiceRecording() {
        if speechRecognizer.isListening {
            // Stop and submit
            speechRecognizer.stopListening()

            let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                submitVoiceInput(transcript)
            }
        } else {
            // Start listening
            Task {
                do {
                    try speechRecognizer.startListening()
                } catch {
                    logger.error("Failed to start speech recognition: \(error)")
                }
            }
        }
    }

    private func submitVoiceInput(_ text: String) {
        Task {
            // Close voice mode
            isVoiceMode = false
            executeTask(text)
        }
    }

    private func executeTask(_ text: String) {
        // Add user message to current session (or create new if needed)
        if let session = sessionStore.currentSession {
            sessionStore.addMessage(
                PeekabooCore.ConversationMessage(role: .user, content: text),
                to: session)
        } else {
            // Create new session if needed
            let newSession = sessionStore.createSession(title: text)
            sessionStore.addMessage(
                PeekabooCore.ConversationMessage(role: .user, content: text),
                to: newSession)
        }

        // Execute the task
        Task {
            do {
                try await agent.executeTask(text)
            } catch {
                logger.error("Failed to execute task: \(error)")
            }
        }
    }
}