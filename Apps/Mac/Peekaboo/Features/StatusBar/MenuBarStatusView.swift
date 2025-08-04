import os.log
import PeekabooCore
import SwiftUI
import Tachikoma

struct MenuBarStatusView: View {
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "MenuBarStatus")

    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    @Environment(\.openWindow) private var openWindow
    @State private var isHovering = false
    @State private var hasAppeared = false
    @State private var isVoiceMode = false
    @State private var inputText = ""
    @State private var refreshTrigger = UUID()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with current status
            self.headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)

            Divider()

            // Main content area - unified experience
            self.unifiedContentView
                .frame(maxHeight: 500)

            Divider()

            // Always show input area and action buttons for consistent experience
            VStack(spacing: 0) {
                // Input area (always visible)
                self.inputAreaView
                    .padding(10)
                    .background(.regularMaterial)

                Divider()

                // Action buttons (always visible)
                self.actionButtonsView
                    .padding()
                    .background(.regularMaterial)
            }
        }
        .frame(width: 380)
        .background(.ultraThinMaterial)
        .onAppear {
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

    private var headerView: some View {
        HStack {
            Image(systemName: self.agent.isProcessing ? "brain" : "moon.stars")
                .font(.title2)
                .foregroundColor(self.agent.isProcessing ? .accentColor : .secondary)
                .symbolEffect(.pulse, options: .repeating, isActive: self.agent.isProcessing)

            VStack(alignment: .leading, spacing: 2) {
                if let currentSession = sessionStore.currentSession {
                    Text(currentSession.title)
                        .font(.headline)
                        .lineLimit(1)

                    if self.agent.isProcessing {
                        if let currentTool = agent.toolExecutionHistory.last(where: { $0.status == .running }) {
                            HStack(spacing: 4) {
                                EnhancedToolIcon(
                                    toolName: currentTool.toolName,
                                    status: .running)
                                    .font(.system(size: 12))
                                    .frame(width: 14, height: 14)
                                Text(ToolFormatter.compactToolSummary(
                                    toolName: currentTool.toolName,
                                    arguments: currentTool.arguments ?? ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            Text("Processing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        // Show session duration when idle
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatSessionDuration(currentSession))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(self.agent.isProcessing ? "Agent Active" : "Agent Idle")
                        .font(.headline)
                }
            }

            Spacer()

            // Show token count if available
            if let usage = agent.tokenUsage {
                HStack(spacing: 2) {
                    Image(systemName: "circle.hexagongrid.circle")
                        .font(.caption)
                    Text("\(usage.totalTokens)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .help("Tokens: \(usage.inputTokens) in, \(usage.outputTokens) out")
            }

            // Voice mode toggle button
            if !self.agent.isProcessing {
                Button(action: { self.isVoiceMode.toggle() }) {
                    Image(systemName: self.isVoiceMode ? "keyboard" : "mic")
                        .font(.title3)
                        .foregroundColor(self.isVoiceMode ? .red : .accentColor)
                        .symbolEffect(
                            .pulse,
                            options: .repeating,
                            isActive: self.isVoiceMode && self.speechRecognizer.isListening)
                }
                .buttonStyle(.plain)
                .help(self.isVoiceMode ? "Switch to text input" : "Switch to voice input")
            }

            if self.agent.isProcessing {
                Button(action: {
                    self.agent.cancelCurrentTask()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Cancel current task")
            }
        }
    }

    // MARK: - Unified Content View

    private var unifiedContentView: some View {
        Group {
            if self.sessionStore.currentSession != nil {
                // Show unified activity feed for current session
                UnifiedActivityFeed()
            } else if !self.sessionStore.sessions.isEmpty {
                // Show recent sessions when no active session
                self.recentSessionsView
            } else {
                // Empty state
                self.emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5))

            Text("Welcome to Peekaboo")
                .font(.title3)
                .fontWeight(.medium)

            Text("Ask me to help you with automation tasks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Input Area View

    private var inputAreaView: some View {
        HStack(spacing: 8) {
            if self.isVoiceMode {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            TextField(self.agent.isProcessing ? "Ask a follow-up..." : "Ask Peekaboo...", text: self.$inputText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused(self.$isInputFocused)
                .onSubmit {
                    self.submitInput()
                }

            // Voice mode toggle
            Button(action: { self.isVoiceMode.toggle() }) {
                Image(systemName: self.isVoiceMode ? "keyboard" : "mic")
                    .font(.body)
                    .foregroundColor(self.isVoiceMode ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(self.isVoiceMode ? "Switch to text input" : "Switch to voice input")

            Button(action: self.submitInput) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(self.inputText.isEmpty && !self.isVoiceMode)
        }
    }

    private func submitInput() {
        let text = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

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

        self.inputText = ""

        // Execute the task
        Task {
            do {
                try await self.agent.executeTask(text)
            } catch {
                print("Failed to execute task: \(error)")
            }
        }
    }

    private func submitFollowUp() {
        let text = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message to current session
        if let session = sessionStore.currentSession {
            self.sessionStore.addMessage(
                PeekabooCore.ConversationMessage(role: .user, content: text),
                to: session)
        }

        self.inputText = ""

        // Execute the task
        Task {
            do {
                try await self.agent.executeTask(text)
            } catch {
                print("Failed to execute task: \(error)")
            }
        }
    }

    @ViewBuilder
    private var recentSessionsView: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(self.sessionStore.sessions.prefix(5)) { session in
                    SessionRowCompact(
                        session: session,
                        isActive: self.agent.currentSession?.id == session.id,
                        onDelete: {
                            withAnimation {
                                self.sessionStore.sessions.removeAll { $0.id == session.id }
                                Task {
                                    self.sessionStore.saveSessions()
                                }
                            }
                        })
                        .onTapGesture {
                            self.sessionStore.selectSession(session)
                            // Don't open main window - keep the popover experience
                        }
                }

                if self.sessionStore.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Text("No recent sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Start by asking me something")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var idleStateWithInput: some View {
        VStack(spacing: 16) {
            // Header with ghost icon
            VStack(spacing: 8) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                    .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5))

                Text("Ask Peekaboo")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.top)

            // Input field - always visible
            HStack(spacing: 8) {
                if self.isVoiceMode {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                TextField("What would you like me to do?", text: self.$inputText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused(self.$isInputFocused)
                    .onSubmit {
                        self.submitInput()
                    }

                Button(action: self.submitInput) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(self.inputText.isEmpty)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            // Recent sessions if any
            if !self.sessionStore.sessions.isEmpty {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(self.sessionStore.sessions.prefix(3)) { session in
                                HStack {
                                    Text(session.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Text(formatSessionDuration(session))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                                .cornerRadius(4)
                                .onTapGesture {
                                    self.sessionStore.selectSession(session)
                                    // Don't open main window - just load the session
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 100)
                }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            // Session picker / current session indicator
            if let currentSession = sessionStore.currentSession {
                HStack {
                    Image(systemName: "text.bubble")
                        .font(.caption)
                    Text(currentSession.title)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
            } else {
                Button(action: self.createNewSession) {
                    Label("New Session", systemImage: "plus.circle")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }

            Button(action: self.openMainWindow) {
                Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var quickActionsView: some View {
        VStack(spacing: 8) {
            Button(action: self.openMainWindow) {
                Label("Open Main Window", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)

            Button(action: self.createNewSession) {
                Label("New Session", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }

    private func openMainWindow() {
        self.logger.info("Opening main window")

        // Show dock icon temporarily
        DockIconManager.shared.temporarilyShowDock()

        // Activate the app
        NSApp.activate(ignoringOtherApps: true)

        // Use SwiftUI's openWindow directly
        self.openWindow(id: "main")
    }

    private func createNewSession() {
        self.logger.info("Creating new session")

        // Create a new session first
        _ = self.sessionStore.createSession(title: "New Session")

        // Then open the main window
        self.openMainWindow()
    }

    private var voiceInputView: some View {
        VStack(spacing: 16) {
            // Listening indicator
            VStack(spacing: 8) {
                if self.speechRecognizer.isListening {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .scaleEffect(self.speechRecognizer.isListening ? 1.2 : 0.8)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: self.speechRecognizer.isListening)
                        }
                    }
                    .frame(height: 20)
                }

                Text(self.speechRecognizer.transcript.isEmpty ? "Listening..." : self.speechRecognizer.transcript)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(maxHeight: 100)
            }

            // Microphone button
            Button {
                self.toggleVoiceRecording()
            } label: {
                Image(systemName: self.speechRecognizer.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(self.speechRecognizer.isListening ? .red : .accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(minHeight: 200)
    }

    // MARK: - Actions

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
                    // Handle error - could show alert or status
                    print("Failed to start speech recognition: \(error)")
                }
            }
        }
    }

    private func submitVoiceInput(_ text: String) {
        Task {
            // Close voice mode
            self.isVoiceMode = false

            // Execute the task
            do {
                try await self.agent.executeTask(text)
            } catch {
                // Handle error - could show in UI
                print("Task execution error: \(error)")
            }
        }
    }
}

// Compact session row for menu bar
struct SessionRowCompact: View {
    let session: ConversationSession
    let isActive: Bool
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.session.title)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatSessionDuration(self.session))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if self.isHovering, !self.isActive {
                Button(action: self.onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete session")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .cornerRadius(6)
        .padding(.horizontal)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
}

// MARK: - MenuBarStatusView Extensions

extension MenuBarStatusView {
    private func currentSessionPreview(_ session: ConversationSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Session header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(session.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                Spacer()

                // Open button
                Button(action: self.openMainWindow) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Open in main window")
            }

            // Show last few messages
            if !session.messages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(session.messages.suffix(3)) { message in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: self.iconForRole(message.role))
                                .font(.caption2)
                                .foregroundColor(self.colorForRole(message.role))
                                .frame(width: 12)

                            Text(self.truncatedContent(message.content))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(6)
            }

            // Session stats
            HStack(spacing: 12) {
                Label("\(session.messages.count)", systemImage: "message")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if self.agent.tokenUsage != nil {
                    Label("\(self.agent.tokenUsage?.totalTokens ?? 0)", systemImage: "circle.hexagongrid.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatSessionDuration(session))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(8)
    }

    private func iconForRole(_ role: MessageRole) -> String {
        switch role {
        case .user: "person.circle"
        case .assistant: "brain"
        case .system: "gear"
        }
    }

    private func colorForRole(_ role: MessageRole) -> Color {
        switch role {
        case .user: .blue
        case .assistant: .green
        case .system: .orange
        }
    }

    private func truncatedContent(_ content: String) -> String {
        let cleaned = content
            .replacingOccurrences(of: "🤔 ", with: "")
            .replacingOccurrences(of: "🔧 ", with: "")
            .replacingOccurrences(of: "✅ ", with: "")
            .replacingOccurrences(of: "❌ ", with: "")
            .replacingOccurrences(of: "⚠️ ", with: "")
            .components(separatedBy: .newlines)
            .first ?? content

        return String(cleaned.prefix(50)) + (cleaned.count > 50 ? "..." : "")
    }
}

// MARK: - Helper Functions

private func formatSessionDuration(_ session: ConversationSession) -> String {
    let duration: TimeInterval

        // If there's a last message, calculate duration from start to last message
        = if let lastMessage = session.messages.last
    {
        lastMessage.timestamp.timeIntervalSince(session.startTime)
    } else {
        // Otherwise just show time since start
        Date().timeIntervalSince(session.startTime)
    }

    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2

    return formatter.string(from: duration) ?? "0s"
}
