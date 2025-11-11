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
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer {
                    self.contentStack
                }
                .padding(18)
                .glassBackground(
                    cornerRadius: 28,
                    tintColor: NSColor(calibratedWhite: 0.04, alpha: 0.75))
                .overlay(StatusBarChromeOverlay(cornerRadius: 28))
            } else {
                self.contentStack
                    .padding(18)
                    .modernBackground(style: .popover, cornerRadius: 28)
                    .overlay(StatusBarChromeOverlay(cornerRadius: 28))
            }
        }
        .frame(width: 420)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
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

// MARK: - Layout Helpers

extension MenuBarStatusView {
    private var contentStack: some View {
        VStack(spacing: 14) {
            self.headerSection
            self.timelineSection
            self.inputSection
            self.actionsSection
        }
    }

    private var headerSection: some View {
        StatusBarHeaderView(isVoiceMode: self.$isVoiceMode)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassSurface(style: .toolbar, cornerRadius: 22)
    }

    private var timelineSection: some View {
        StatusBarContentView()
            .frame(maxHeight: 440)
            .glassSurface(style: .content, cornerRadius: 24)
    }

    @ViewBuilder
    private var inputSection: some View {
        Group {
            if self.isVoiceMode {
                VoiceInputView(onToggleRecording: self.toggleVoiceRecording)
            } else {
                StatusBarInputView(
                    inputText: self.$inputText,
                    isVoiceMode: self.$isVoiceMode,
                    isInputFocused: self.$isInputFocused,
                    isProcessing: self.agent.isProcessing,
                    onSubmit: self.submitInput)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassSurface(style: .content, cornerRadius: 20)
    }

    private var actionsSection: some View {
        ActionButtonsView()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassSurface(style: .toolbar, cornerRadius: 18)
    }
}

// MARK: - Chrome Overlay

private struct StatusBarChromeOverlay: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.35),
                        Color.white.opacity(0.05),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                lineWidth: 0.8)
            .overlay {
                RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.black.opacity(0.2),
                            ],
                            startPoint: .top,
                            endPoint: .bottom))
                    .blendMode(.softLight)
            }
            .allowsHitTesting(false)
    }
}
