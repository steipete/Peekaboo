import SwiftUI
import PeekabooCore

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

    enum InputMode {
        case text
        case voice
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
        .frame(minWidth: 600, idealWidth: 800, maxWidth: 1200,
               minHeight: 400, idealHeight: 600, maxHeight: 800)
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
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image("ghost.idle")
                .resizable()
                .frame(width: 24, height: 24)

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
            if isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .symbolEffect(.pulse, options: .repeating)
                    
                    if let startTime = recordingStartTime {
                        Text(timeIntervalString(from: startTime))
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
            }
            
            // Session list button
            Button {
                showSessionList.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show sessions")
            .popover(isPresented: $showSessionList) {
                SessionListPopover()
                    .environment(sessionStore)
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
            Image("ghost.peek1")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.secondary)

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
        .frame(height: 100)
    }

    // MARK: - Actions

    private func submitInput() {
        let trimmedInput = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        Task {
            self.isProcessing = true
            defer { isProcessing = false }
            
            // Start recording if not already
            if !isRecording {
                startRecording()
            }

            do {
                try await agent.executeTask(trimmedInput)
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }

            // Clear input
            self.inputText = ""
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingStartTime = Date()
        
        // Create new session if needed
        if sessionStore.currentSession == nil {
            _ = sessionStore.createSession(title: "Recording \(Date().formatted(date: .abbreviated, time: .shortened))")
        }
    }
    
    private func stopRecording() {
        isRecording = false
        recordingStartTime = nil
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

            let transcript = self.speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                self.inputText = transcript
                self.submitInput()
            }
        } else {
            // Start listening
            Task {
                do {
                    try self.speechRecognizer.startListening()
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: SessionMessage

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
                            ToolCallView(toolCall: toolCall)
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
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            if sessionStore.sessions.isEmpty {
                VStack {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No sessions yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(sessionStore.sessions) { session in
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
                        sessionStore.selectSession(session)
                        dismiss()
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ToolCall

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.fill")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(self.toolCall.name)
                .font(.caption)
                .foregroundColor(.secondary)

            if !self.toolCall.result.isEmpty {
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(self.toolCall.result)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
}
