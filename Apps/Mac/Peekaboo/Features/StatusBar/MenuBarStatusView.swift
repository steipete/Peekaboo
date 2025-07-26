import SwiftUI
import os.log

struct MenuBarStatusView: View {
    private let logger = Logger(subsystem: "com.steipete.Peekaboo", category: "MenuBarStatus")
    
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    @State private var isHovering = false
    @State private var hasAppeared = false
    @State private var isVoiceMode = false
    @State private var inputText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with current status
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main content area
            Group {
                if agent.isProcessing {
                    activeSessionView
                } else {
                    idleView
                }
            }
            .frame(minHeight: 200)
        }
        .frame(width: 400)
        .frame(minHeight: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            hasAppeared = true
            // Force a UI update in case environment values weren't ready
            DispatchQueue.main.async {
                self.hasAppeared = true
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: agent.isProcessing ? "brain" : "moon.stars")
                .font(.title2)
                .foregroundColor(agent.isProcessing ? .accentColor : .secondary)
                .symbolEffect(.pulse, options: .repeating, isActive: agent.isProcessing)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.isProcessing ? "Agent Active" : "Agent Idle")
                    .font(.headline)
                
                if agent.isProcessing {
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Voice mode toggle button
            if !agent.isProcessing {
                Button(action: { isVoiceMode.toggle() }) {
                    Image(systemName: isVoiceMode ? "keyboard" : "mic")
                        .font(.title3)
                        .foregroundColor(isVoiceMode ? .red : .accentColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: isVoiceMode && speechRecognizer.isListening)
                }
                .buttonStyle(.plain)
                .help(isVoiceMode ? "Switch to text input" : "Switch to voice input")
            }
            
            if agent.isProcessing {
                Button(action: { 
                    agent.cancelCurrentTask()
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
    
    private var activeSessionView: some View {
        Group {
            if let session = sessionStore.currentSession {
                VStack(spacing: 0) {
                    // Active task indicator
                    if agent.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle())
                            
                            Text("Processing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: { 
                                agent.cancelCurrentTask()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Cancel current task")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        
                        Divider()
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                if session.messages.isEmpty {
                                    // Show loading state when session exists but no messages yet
                                    VStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            ForEach(0..<3) { index in
                                                Circle()
                                                    .fill(Color.accentColor)
                                                    .frame(width: 6, height: 6)
                                                    .scaleEffect(1.2)
                                                    .animation(
                                                        Animation.easeInOut(duration: 0.8)
                                                            .repeatForever()
                                                            .delay(Double(index) * 0.2),
                                                        value: agent.isProcessing
                                                    )
                                            }
                                        }
                                        
                                        Text("Initializing task...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                } else {
                                    ForEach(session.messages) { message in
                                        MessageRowCompact(message: message)
                                            .id(message.id)
                                    }
                                    
                                    // Show thinking indicator if last message is thinking
                                    if let lastMessage = session.messages.last,
                                       lastMessage.role == .system,
                                       lastMessage.content.contains("🤔") {
                                        ThinkingIndicator()
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .padding()
                            .onChange(of: session.messages.count) { _, _ in
                                // Auto-scroll to bottom on new messages
                                if let lastMessage = session.messages.last {
                                    withAnimation {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    
                    // Input area for chatting during execution
                    if agent.isProcessing {
                        Divider()
                        
                        HStack(spacing: 8) {
                            TextField("Ask a follow-up question...", text: $inputText)
                                .textFieldStyle(.plain)
                                .font(.caption)
                                .onSubmit {
                                    submitFollowUp()
                                }
                            
                            Button(action: submitFollowUp) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.body)
                            }
                            .buttonStyle(.plain)
                            .disabled(inputText.isEmpty)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
            } else {
                // Fallback when agent is executing but session not created yet
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Initializing session...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: 200)
                .padding()
            }
        }
    }
    
    private func submitFollowUp() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message to current session
        if let session = sessionStore.currentSession {
            sessionStore.addMessage(
                SessionMessage(role: .user, content: text),
                to: session
            )
        }
        
        inputText = ""
        
        // Send follow-up to agent if one is active
        if agent.isProcessing {
            // Queue the message for later processing
            agent.queueMessage(text)
        } else {
            // Start a new execution with the follow-up
            Task {
                do {
                    try await agent.executeTask(text)
                } catch {
                    print("Failed to execute task: \(error)")
                }
            }
        }
    }
    
    private var idleView: some View {
        VStack(spacing: 16) {
            // Show voice input UI when in voice mode
            if isVoiceMode {
                voiceInputView
            }
            
            // Recent sessions (show when not in voice mode)
            if !isVoiceMode && !sessionStore.sessions.isEmpty {
                recentSessionsView
                    .padding(.top)
            }
            
            // Quick actions
            quickActionsView
                .padding()
        }
    }
    
    @ViewBuilder
    private var recentSessionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(sessionStore.sessions.prefix(5)) { session in
                        SessionRowCompact(
                            session: session,
                            isActive: false, // Simplified check
                            onDelete: {
                                withAnimation {
                                    sessionStore.sessions.removeAll { $0.id == session.id }
                                    sessionStore.saveSessions()
                                }
                            }
                        )
                        .onTapGesture {
                            sessionStore.selectSession(session)
                            // Show dock icon temporarily
                            DockIconManager.shared.temporarilyShowDock()
                            // Open main window
                            NotificationCenter.default.post(name: Notification.Name("OpenWindow.main"), object: nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
    
    @ViewBuilder
    private var quickActionsView: some View {
        VStack(spacing: 8) {
            Button(action: {
                logger.info("Open Main Window button clicked")
                // Show dock icon temporarily
                DockIconManager.shared.temporarilyShowDock()
                // Post notification to open window
                NotificationCenter.default.post(name: Notification.Name("OpenWindow.main"), object: nil)
                // Activate the app
                NSApp.activate(ignoringOtherApps: true)
            }) {
                Label("Open Main Window", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            
            Button(action: {
                logger.info("New Session button clicked")
                // Show dock icon temporarily
                DockIconManager.shared.temporarilyShowDock()
                // First open main window
                NotificationCenter.default.post(name: Notification.Name("OpenWindow.main"), object: nil)
                NSApp.activate(ignoringOtherApps: true)
                
                // Then start new session after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    logger.info("Posting StartNewSession notification")
                    NotificationCenter.default.post(name: Notification.Name("StartNewSession"), object: nil)
                }
            }) {
                Label("New Session", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var voiceInputView: some View {
        VStack(spacing: 16) {
            // Listening indicator
            VStack(spacing: 8) {
                if speechRecognizer.isListening {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .scaleEffect(speechRecognizer.isListening ? 1.2 : 0.8)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: speechRecognizer.isListening
                                )
                        }
                    }
                    .frame(height: 20)
                }
                
                Text(speechRecognizer.transcript.isEmpty ? "Listening..." : speechRecognizer.transcript)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(maxHeight: 100)
            }
            
            // Microphone button
            Button {
                toggleVoiceRecording()
            } label: {
                Image(systemName: speechRecognizer.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(speechRecognizer.isListening ? .red : .accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(minHeight: 200)
    }
    
    // MARK: - Actions
    
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
                    // Handle error - could show alert or status
                    print("Failed to start speech recognition: \(error)")
                }
            }
        }
    }
    
    private func submitVoiceInput(_ text: String) {
        Task {
            // Close voice mode
            isVoiceMode = false
            
            // Execute the task
            do {
                try await agent.executeTask(text)
            } catch {
                // Handle error - could show in UI
                print("Task execution error: \(error)")
            }
        }
    }
}

// Thinking indicator view
struct ThinkingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")
                .font(.caption)
                .foregroundColor(.purple)
                .symbolEffect(.pulse, options: .repeating)
            
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 4, height: 4)
                        .offset(y: animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(index) * 0.1),
                            value: animationOffset
                        )
                }
            }
            
            Text("Thinking...")
                .font(.caption)
                .foregroundColor(.purple)
                .italic()
        }
        .padding(.vertical, 4)
        .onAppear {
            animationOffset = -3
        }
    }
}

// Compact message row for menu bar
struct MessageRowCompact: View {
    let message: SessionMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Role icon
            Image(systemName: iconForRole)
                .font(.caption)
                .foregroundColor(colorForRole)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                if message.role == .system && message.content.contains("🤔") {
                    // Special formatting for thinking messages
                    Text(message.content.replacingOccurrences(of: "🤔 ", with: ""))
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                } else if message.role == .system && message.content.contains("❌") {
                    // Error messages
                    Text(message.content)
                        .font(.caption)
                        .foregroundColor(.red)
                } else if message.role == .system && message.content.contains("⚠️") {
                    // Warning/cancelled messages
                    Text(message.content)
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(message.content)
                        .font(.caption)
                        .lineLimit(2)
                }
                
                // Show tool calls inline
                ForEach(message.toolCalls) { toolCall in
                    HStack(spacing: 4) {
                        if toolCall.result == "Running..." {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        
                        Text(toolCall.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if !toolCall.result.isEmpty && toolCall.result != "Running..." {
                            Text("✓")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(backgroundForRole)
        .cornerRadius(6)
    }
    
    private var iconForRole: String {
        switch message.role {
        case .user: return "person.circle"
        case .assistant: return "brain"
        case .system: return "gear"
        }
    }
    
    private var colorForRole: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .orange
        }
    }
    
    private var backgroundForRole: Color {
        switch message.role {
        case .user: return Color.blue.opacity(0.1)
        case .assistant: return Color.green.opacity(0.1)
        case .system: return Color.orange.opacity(0.1)
        }
    }
}

// Compact session row for menu bar
struct SessionRowCompact: View {
    let session: Session
    let isActive: Bool
    let onDelete: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(session.startTime, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isHovering && !isActive {
                Button(action: onDelete) {
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
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .padding(.horizontal)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

