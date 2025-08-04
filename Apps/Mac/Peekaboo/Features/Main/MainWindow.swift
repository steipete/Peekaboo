import PeekabooCore
import SwiftUI

struct MainWindow: View {
    @Environment(PeekabooSettings.self) private var settings
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    @Environment(Permissions.self) private var permissions

    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var inputMode: InputMode = .text
    @State private var isRecording = false
    @State private var recordingStartTime: Date?
    @State private var showSessionList = false
    @State private var showRecognitionModeMenu = false

    enum InputMode {
        case text
        case voice
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { self.errorMessage != nil },
            set: { if !$0 { self.errorMessage = nil } })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            self.headerView

            Divider()

            // Content
            if !self.settings.hasValidAPIKey {
                OnboardingView()
            } else if !self.permissions.hasAllPermissions {
                PermissionsView()
            } else {
                self.chatView
            }
        }
        .frame(
            minWidth: 600,
            idealWidth: 800,
            maxWidth: 1200,
            minHeight: 400,
            idealHeight: 600,
            maxHeight: 800)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await self.permissions.check()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartNewSession"))) { _ in
            // Clear current input and focus on text field
            self.inputText = ""
            self.inputMode = .text
            // The text field will automatically focus when available
        }
        .alert("Error", isPresented: self.showErrorAlert) {
            Button("OK") {
                self.errorMessage = nil
            }
        } message: {
            Text(self.errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            GhostImageView(state: .idle, size: CGSize(width: 24, height: 24))

            Text("Peekaboo")
                .font(.headline)

            if let session = sessionStore.currentSession {
                Text("•")
                    .foregroundColor(.secondary)
                Text(session.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Recording indicator
            if self.isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .symbolEffect(.pulse, options: .repeating)

                    if let startTime = recordingStartTime {
                        Text(self.timeIntervalString(from: startTime))
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
            }

            // Session list button
            Button {
                self.showSessionList.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show sessions")
            .popover(isPresented: self.$showSessionList) {
                SessionListPopover()
                    .environment(self.sessionStore)
                    .frame(width: 300, height: 400)
            }

            Button {
                self.inputMode = self.inputMode == .text ? .voice : .text
            } label: {
                Image(systemName: self.inputMode == .text ? "mic" : "keyboard")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(self.inputMode == .text ? "Switch to voice input" : "Switch to text input")
        }
        .padding()
    }

    // MARK: - Chat View

    private var chatView: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if let session = sessionStore.currentSession {
                            ForEach(session.messages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .push(from: .bottom).combined(with: .opacity),
                                        removal: .opacity))
                                    .animation(
                                        .spring(response: 0.3, dampingFraction: 0.8),
                                        value: session.messages.count)
                            }
                        } else {
                            self.emptyStateView
                        }
                    }
                    .padding()
                }
                .onChange(of: self.sessionStore.currentSession?.messages.count ?? 0) { _, _ in
                    // Scroll to bottom when new messages arrive
                    if let lastMessage = sessionStore.currentSession?.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            if self.inputMode == .text {
                self.textInputView
            } else {
                self.voiceInputView
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            GhostImageView(state: .peek1, size: CGSize(width: 64, height: 64))

            Text("Hi! I'm Peekaboo")
                .font(.title2)

            Text("I can help you automate tasks on your Mac")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                self.suggestionButton("Take a screenshot of Safari")
                self.suggestionButton("Click on the search button")
                self.suggestionButton("Type 'Hello world'")
                self.suggestionButton("What's on my screen?")
                self.suggestionButton("Open System Settings")
                self.suggestionButton("Show me the dock")
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func suggestionButton(_ text: String) -> some View {
        Button {
            self.inputText = text
            self.submitInput()
        } label: {
            HStack {
                Image(systemName: "sparkle")
                    .font(.caption)
                Text(text)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text Input

    private var textInputView: some View {
        HStack(spacing: 8) {
            TextField("Ask me to do something...", text: self.$inputText)
                .textFieldStyle(.plain)
                .onSubmit {
                    self.submitInput()
                }

            Button {
                self.submitInput()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.isProcessing)
        }
        .padding()
    }

    // MARK: - Voice Input

    private var voiceInputView: some View {
        VStack(spacing: 16) {
            // Recognition mode selector
            HStack {
                Text("Recognition:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Menu {
                    ForEach(RecognitionMode.allCases, id: \.self) { mode in
                        Button {
                            self.speechRecognizer.recognitionMode = mode
                        } label: {
                            HStack {
                                Text(mode.rawValue)
                                if mode == self.speechRecognizer.recognitionMode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .disabled(mode.requiresOpenAIKey && self.settings.openAIAPIKey.isEmpty)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(self.speechRecognizer.recognitionMode.rawValue)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .help(self.speechRecognizer.recognitionMode.description)
            }

            if self.speechRecognizer.isListening {
                // Listening state
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(self.speechRecognizer.isListening ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: self.speechRecognizer.isListening)
                    }
                }

                Text(self.speechRecognizer.transcript.isEmpty ? "Listening..." : self.speechRecognizer.transcript)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(minHeight: 40)
            }

            // Show error if present
            if let error = speechRecognizer.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

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
        .frame(minHeight: 140)
    }

    // MARK: - Actions

    private func submitInput() {
        let trimmedInput = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        Task {
            self.isProcessing = true
            defer { isProcessing = false }

            // Start recording if not already
            if !self.isRecording {
                self.startRecording()
            }

            do {
                try await self.agent.executeTask(trimmedInput)
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }

            // Clear input
            self.inputText = ""
        }
    }

    private func submitAudioInput(audioData: Data, duration: TimeInterval, transcript: String? = nil) {
        Task {
            self.isProcessing = true
            defer { isProcessing = false }

            // Start recording if not already
            if !self.isRecording {
                self.startRecording()
            }

            do {
                // Execute task with audio content
                try await self.agent.executeTaskWithAudio(
                    audioData: audioData,
                    duration: duration,
                    mimeType: "audio/wav",
                    transcript: transcript)

                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func startRecording() {
        self.isRecording = true
        self.recordingStartTime = Date()

        // Create new session if needed
        if self.sessionStore.currentSession == nil {
            _ = self.sessionStore
                .createSession(title: "Recording \(Date().formatted(date: .abbreviated, time: .shortened))")
        }
    }

    private func stopRecording() {
        self.isRecording = false
        self.recordingStartTime = nil
    }

    private func timeIntervalString(from startTime: Date) -> String {
        let interval = Date().timeIntervalSince(startTime)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func toggleVoiceRecording() {
        if self.speechRecognizer.isListening {
            // Stop and submit
            self.speechRecognizer.stopListening()

            // Handle different recognition modes
            switch self.speechRecognizer.recognitionMode {
            case .native, .whisper, .tachikoma:
                // For native, whisper, and tachikoma, use the transcript
                let transcript = self.speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !transcript.isEmpty {
                    self.inputText = transcript
                    self.submitInput()
                }

            case .direct:
                // For direct mode, we'll submit the audio data
                if let audioData = self.speechRecognizer.recordedAudioData,
                   let duration = self.speechRecognizer.recordedAudioDuration
                {
                    // Submit as audio message with transcript if available
                    let transcript = self.speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.submitAudioInput(
                        audioData: audioData,
                        duration: duration,
                        transcript: transcript.isEmpty ? nil : transcript)
                }
            }
        } else {
            // Start listening
            Task {
                do {
                    try self.speechRecognizer.startListening()

                    // Monitor for errors during recording
                    if let error = self.speechRecognizer.error {
                        self.errorMessage = error.localizedDescription
                        // Don't switch back to text for API key errors, just show the error
                        if !(error is SpeechError && error as! SpeechError == .apiKeyRequired) {
                            self.inputMode = .text
                        }
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.inputMode = .text // Switch back to text mode on error
                }
            }
        }
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: ConversationMessage
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Image(systemName: self.iconName)
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(self.message.content)
                    .textSelection(.enabled)

                if !self.message.toolCalls.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(self.message.toolCalls) { toolCall in
                            MainWindowToolCallView(toolCall: toolCall)
                        }
                    }
                    .padding(.top, 4)
                }

                Text(self.message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .scaleEffect(self.appeared ? 1 : 0.8)
        .opacity(self.appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.appeared = true
            }
        }
    }

    private var iconName: String {
        switch self.message.role {
        case .user:
            "person.fill"
        case .assistant:
            "sparkles"
        case .system:
            "gear"
        }
    }
}

// MARK: - Session List Popover

struct SessionListPopover: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Button(action: { self.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if self.sessionStore.sessions.isEmpty {
                VStack {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No sessions yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(self.sessionStore.sessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title)
                                .font(.body)
                                .lineLimit(1)

                            Text("\(session.messages.count) messages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.sessionStore.selectSession(session)
                        self.dismiss()
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Tool Call View

struct MainWindowToolCallView: View {
    let toolCall: ConversationToolCall
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Tool execution summary
            HStack(spacing: 4) {
                AnimatedToolIcon(
                    toolName: self.toolCall.name,
                    isRunning: false)

                Text(self.toolSummary)
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            // Result summary if available
            if let resultSummary = self.resultSummary {
                HStack(spacing: 4) {
                    Text("→")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20) // Align with icon

                    Text(resultSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
        .scaleEffect(self.appeared ? 1 : 0.8)
        .opacity(self.appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8).delay(0.1)) {
                self.appeared = true
            }
        }
    }

    private var toolSummary: String {
        // Use ToolFormatter to get a human-readable summary
        ToolFormatter.compactToolSummary(
            toolName: self.toolCall.name,
            arguments: self.toolCall.arguments)
    }

    private var resultSummary: String? {
        // Use ToolFormatter to extract meaningful result information
        ToolFormatter.toolResultSummary(
            toolName: self.toolCall.name,
            result: self.toolCall.result)
    }
}
