import SwiftUI
import os.log
import PeekabooCore

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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with current status
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            
            Divider()
            
            // Main content area - always show current session if available
            if let currentSession = sessionStore.currentSession {
                currentSessionView(currentSession)
                    .frame(maxHeight: 350)
            } else if agent.isProcessing {
                // Fallback when agent is processing but no session yet
                activeSessionView
                    .frame(maxHeight: 350)
            } else {
                // Empty state when no session
                emptyStateView
                    .frame(minHeight: 150)
            }
            
            Divider()
            
            // Bottom action buttons
            actionButtonsView
                .padding()
                .background(.regularMaterial)
        }
        .frame(width: 380)
        .background(.ultraThinMaterial)
        .onAppear {
            hasAppeared = true
            // Force a UI update in case environment values weren't ready
            DispatchQueue.main.async {
                self.hasAppeared = true
                self.refreshTrigger = UUID()
            }
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
    
    private var headerView: some View {
        HStack {
            Image(systemName: agent.isProcessing ? "brain" : "moon.stars")
                .font(.title2)
                .foregroundColor(agent.isProcessing ? .accentColor : .secondary)
                .symbolEffect(.pulse, options: .repeating, isActive: agent.isProcessing)
            
            VStack(alignment: .leading, spacing: 2) {
                if let currentSession = sessionStore.currentSession {
                    Text(currentSession.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if agent.isProcessing {
                        if let currentTool = agent.toolExecutionHistory.last(where: { $0.status == .running }) {
                            HStack(spacing: 4) {
                                EnhancedToolIcon(
                                    toolName: currentTool.toolName,
                                    status: .running
                                )
                                .font(.system(size: 12))
                                .frame(width: 14, height: 14)
                                Text(ToolFormatter.compactToolSummary(toolName: currentTool.toolName, arguments: currentTool.arguments))
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
                    Text(agent.isProcessing ? "Agent Active" : "Agent Idle")
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
                .help("Tokens: \(usage.promptTokens) in, \(usage.completionTokens) out")
            }
            
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
    
    private func currentSessionView(_ session: ConversationSession) -> some View {
        VStack(spacing: 0) {
            // Tool execution history (showing recent tools)
            if !agent.toolExecutionHistory.isEmpty {
                VStack(spacing: 4) {
                    // Show current running tool prominently
                    if let currentTool = agent.toolExecutionHistory.last(where: { $0.status == .running }) {
                        HStack(spacing: 8) {
                            EnhancedToolIcon(
                                toolName: currentTool.toolName,
                                status: .running
                            )
                            .font(.system(size: 16))
                            .frame(width: 20, height: 20)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ToolFormatter.compactToolSummary(toolName: currentTool.toolName, arguments: currentTool.arguments))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                // Show elapsed time for running tool
                                TimeIntervalText(startTime: currentTool.timestamp)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { agent.cancelCurrentTask() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Cancel current task")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                    }
                    
                    // Show recent completed tools
                    ForEach(agent.toolExecutionHistory.suffix(3).reversed()) { tool in
                        if tool.status != .running {
                            HStack(spacing: 6) {
                                EnhancedToolIcon(
                                    toolName: tool.toolName,
                                    status: tool.status
                                )
                                .font(.system(size: 12))
                                .frame(width: 14, height: 14)
                                
                                Text(ToolFormatter.compactToolSummary(toolName: tool.toolName, arguments: tool.arguments))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Duration for completed tools
                                if let duration = tool.duration {
                                    Text(ToolFormatter.formatDuration(duration))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .opacity(0.7)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                            .opacity(0.7)
                        }
                    }
                }
                .background(Color.secondary.opacity(0.05))
                
                Divider()
            }
            
            Divider()
            
            // Messages scroll view
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Show all messages including system messages
                        ForEach(session.messages) { message in
                            MenuDetailedMessageRow(message: message)
                                .id(message.id)
                        }
                        
                        // Thinking is now handled within MenuDetailedMessageRow
                        
                        // Show processing indicator if actively processing but no thinking message
                        if agent.isProcessing && !agent.isThinking {
                            if let lastMessage = session.messages.last,
                               lastMessage.role != .system || !lastMessage.content.contains("🤔") {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .progressViewStyle(CircularProgressViewStyle())
                                    
                                    Text("Processing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .id("processing")
                            }
                        }
                    }
                    .padding()
                    .onChange(of: session.messages.count) { _, _ in
                        // Auto-scroll to bottom on new messages
                        withAnimation {
                            if let lastMessage = session.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: agent.isProcessing) { _, _ in
                        // Auto-scroll when processing state changes
                        withAnimation {
                            if agent.isProcessing {
                                proxy.scrollTo("processing", anchor: .bottom)
                            } else if let lastMessage = session.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Input area (shown when idle or processing)
            Divider()
            
            HStack(spacing: 8) {
                if isVoiceMode {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                TextField(agent.isProcessing ? "Ask a follow-up..." : "Ask Peekaboo...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit {
                        submitInput()
                    }
                
                Button(action: submitInput) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
            .padding(10)
            .background(.regularMaterial)
        }
    }
    
    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message to current session (or create new if needed)
        if let session = sessionStore.currentSession {
            sessionStore.addMessage(
                ConversationMessage(role: .user, content: text),
                to: session
            )
        } else {
            // Create new session if needed
            let newSession = sessionStore.createSession(title: text)
            sessionStore.addMessage(
                ConversationMessage(role: .user, content: text),
                to: newSession
            )
        }
        
        inputText = ""
        
        // Execute the task
        Task {
            do {
                try await agent.executeTask(text)
            } catch {
                print("Failed to execute task: \(error)")
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
                            if let currentTool = agent.toolExecutionHistory.last(where: { $0.status == .running }) {
                                EnhancedToolIcon(
                                    toolName: currentTool.toolName,
                                    status: .running
                                )
                                .font(.system(size: 16))
                                .frame(width: 20, height: 20)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ToolFormatter.compactToolSummary(toolName: currentTool.toolName, arguments: currentTool.arguments))
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    // Show elapsed time for running tool
                                    TimeIntervalText(startTime: currentTool.timestamp)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle())
                                
                                Text("Initializing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
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
                                        MenuDetailedMessageRow(message: message)
                                            .id(message.id)
                                    }
                                    
                                    // Thinking is now handled within MenuDetailedMessageRow
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
                        .background(.regularMaterial)
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
                ConversationMessage(role: .user, content: text),
                to: session
            )
        }
        
        inputText = ""
        
        // Execute the task
        Task {
            do {
                try await agent.executeTask(text)
            } catch {
                print("Failed to execute task: \(error)")
            }
        }
    }
    
    private var idleView: some View {
        VStack(spacing: 16) {
            // Show current session if there is one (even when idle)
            if let currentSession = sessionStore.currentSession {
                currentSessionPreview(currentSession)
                    .padding(.horizontal)
                    .padding(.top)
                
                Divider()
            }
            
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
                                    Task {
                                        sessionStore.saveSessions()
                                    }
                                }
                            }
                        )
                        .onTapGesture {
                            sessionStore.selectSession(session)
                            openMainWindow()
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // Empty state icon
            Image(systemName: "moon.stars")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5))
            
            Text("No active session")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Start a new session or open the main window")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    @ViewBuilder
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Button(action: openMainWindow) {
                Label("Open Window", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .buttonStyle(.bordered)
            
            Button(action: createNewSession) {
                Label("New Session", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
        }
    }
    
    @ViewBuilder
    private var quickActionsView: some View {
        VStack(spacing: 8) {
            Button(action: openMainWindow) {
                Label("Open Main Window", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            
            Button(action: createNewSession) {
                Label("New Session", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func openMainWindow() {
        logger.info("Opening main window")
        
        // Show dock icon temporarily
        DockIconManager.shared.temporarilyShowDock()
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Use SwiftUI's openWindow directly
        openWindow(id: "main")
    }
    
    private func createNewSession() {
        logger.info("Creating new session")
        
        // Create a new session first
        _ = sessionStore.createSession(title: "New Session")
        
        // Then open the main window
        openMainWindow()
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


// Compact session row for menu bar
struct SessionRowCompact: View {
    let session: ConversationSession
    let isActive: Bool
    let onDelete: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.caption)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatSessionDuration(session))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
        .background(.regularMaterial)
        .cornerRadius(6)
        .padding(.horizontal)
        .onHover { hovering in
            isHovering = hovering
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
                Button(action: openMainWindow) {
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
                            Image(systemName: iconForRole(message.role))
                                .font(.caption2)
                                .foregroundColor(colorForRole(message.role))
                                .frame(width: 12)
                            
                            Text(truncatedContent(message.content))
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
                
                if agent.tokenUsage != nil {
                    Label("\(agent.tokenUsage?.totalTokens ?? 0)", systemImage: "circle.hexagongrid.circle")
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
        case .user: return "person.circle"
        case .assistant: return "brain"
        case .system: return "gear"
        }
    }
    
    private func colorForRole(_ role: MessageRole) -> Color {
        switch role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .orange
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
    if let lastMessage = session.messages.last {
        duration = lastMessage.timestamp.timeIntervalSince(session.startTime)
    } else {
        // Otherwise just show time since start
        duration = Date().timeIntervalSince(session.startTime)
    }
    
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2
    
    return formatter.string(from: duration) ?? "0s"
}