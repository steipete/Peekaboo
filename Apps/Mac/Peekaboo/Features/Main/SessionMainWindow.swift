import Combine
import PeekabooCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Visual Effect View for macOS

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = self.material
        view.blendingMode = self.blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = self.material
        nsView.blendingMode = self.blendingMode
    }
}

struct SessionMainWindow: View {
    @Environment(PeekabooSettings.self) private var settings
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    @Environment(Permissions.self) private var permissions

    @State private var selectedSessionId: String?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            SessionSidebar(
                selectedSessionId: self.$selectedSessionId,
                searchText: self.$searchText)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            SessionDetailContainer(selectedSessionId: self.selectedSessionId)
                .toolbar(removing: .sidebarToggle)
        }
        .navigationTitle("Peekaboo Sessions")
        .onAppear {
            self.selectedSessionId = self.sessionStore.currentSession?.id
        }
        .onChange(of: self.sessionStore.currentSession?.id) { _, newId in
            self.selectedSessionId = newId
        }
    }
}

// MARK: - Session Detail Container

struct SessionDetailContainer: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PeekabooAgent.self) private var agent

    let selectedSessionId: String?

    var body: some View {
        if let sessionId = selectedSessionId,
           let session = sessionStore.sessions.first(where: { $0.id == sessionId })
        {
            SessionChatView(session: session)
        } else if let currentSession = sessionStore.currentSession {
            SessionChatView(session: currentSession)
        } else {
            EmptySessionView()
        }
    }
}

// MARK: - Session Sidebar

struct SessionSidebar: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PeekabooAgent.self) private var agent

    @Binding var selectedSessionId: String?
    @Binding var searchText: String

    private var filteredSessions: [ConversationSession] {
        if self.searchText.isEmpty {
            self.sessionStore.sessions
        } else {
            self.sessionStore.sessions.filter { session in
                session.title.localizedCaseInsensitiveContains(self.searchText) ||
                    session.summary.localizedCaseInsensitiveContains(self.searchText) ||
                    session.messages.contains { message in
                        message.content.localizedCaseInsensitiveContains(self.searchText)
                    }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sessions")
                    .font(.headline)

                Spacer()

                Button(action: self.createNewSession) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New Session")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search sessions...", text: self.$searchText)
                    .textFieldStyle(.plain)
                if !self.searchText.isEmpty {
                    Button(action: { self.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Session list
            List(self.filteredSessions, selection: self.$selectedSessionId) { session in
                SessionRow(
                    session: session,
                    isActive: self.agent.currentSession?.id == session.id,
                    onDelete: { self.deleteSession(session) })
                    .tag(session.id)
                    .transition(.asymmetric(
                        insertion: .slide.combined(with: .opacity),
                        removal: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: self.filteredSessions.count)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            self.deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                    .contextMenu {
                        Button("Delete") {
                            self.deleteSession(session)
                        }
                        Button("Duplicate") {
                            self.duplicateSession(session)
                        }
                        Divider()
                        Button("Export...") {
                            self.exportSession(session)
                        }
                    }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top) {
                // Add padding at the top of the list content
                Color.clear
                    .frame(height: 8)
            }
            .onDeleteCommand {
                // Delete the currently selected session
                if let selectedId = selectedSessionId,
                   let session = sessionStore.sessions.first(where: { $0.id == selectedId }),
                   session.id != agent.currentSession?.id
                {
                    self.deleteSession(session)
                }
            }
        }
    }

    private func createNewSession() {
        let newSession = self.sessionStore.createSession(title: "New Session")
        self.selectedSessionId = newSession.id
    }

    private func deleteSession(_ session: ConversationSession) {
        // Don't delete active session
        guard session.id != self.agent.currentSession?.id else { return }

        self.sessionStore.sessions.removeAll { $0.id == session.id }
        Task {
            try? await self.sessionStore.saveSessions()
        }

        if self.selectedSessionId == session.id {
            self.selectedSessionId = nil
        }
    }

    private func duplicateSession(_ session: ConversationSession) {
        var newSession = ConversationSession(title: "\(session.title) (Copy)")
        newSession.messages = session.messages
        newSession.summary = session.summary

        self.sessionStore.sessions.insert(newSession, at: 0)
        Task {
            try? await self.sessionStore.saveSessions()
        }

        self.selectedSessionId = newSession.id
    }

    private func exportSession(_ session: ConversationSession) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(session.title).json"

        savePanel.begin { response in
            guard response == .OK else { return }

            // Capture URL on main thread before Task
            Task { @MainActor in
                guard let url = savePanel.url else { return }

                do {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(session)
                    try data.write(to: url)
                } catch {
                    print("Failed to export session: \(error)")
                }
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ConversationSession
    let isActive: Bool
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(self.session.title)
                    .font(.body)
                    .fontWeight(self.isActive ? .semibold : .regular)
                    .lineLimit(1)

                if self.isActive {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                        .symbolEffect(.pulse, options: .repeating)
                }

                Spacer()

                // Delete button on hover
                if self.isHovering, !self.isActive {
                    Button(action: self.onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete session")
                }
            }

            HStack {
                Text(self.session.startTime, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !self.session.messages.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("\(self.session.messages.count) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !self.session.modelName.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(formatModelName(self.session.modelName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !self.session.summary.isEmpty {
                Text(self.session.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
}

// MARK: - Helper Functions

private func formatModelName(_ model: String) -> String {
    // Shorten common model names for display
    switch model {
    case "gpt-4.1": "GPT-4.1"
    case "gpt-4.1-mini": "GPT-4.1 mini"
    case "gpt-4o": "GPT-4o"
    case "gpt-4o-mini": "GPT-4o mini"
    case "o3": "o3"
    case "o3-pro": "o3 pro"
    case "o4-mini": "o4-mini"
    case "claude-opus-4-20250514": "Claude Opus 4"
    case "claude-sonnet-4-20250514": "Claude Sonnet 4"
    case "claude-3-5-haiku": "Claude 3.5 Haiku"
    case "claude-3-5-sonnet": "Claude 3.5 Sonnet"
    case "llava:latest": "LLaVA"
    case "llama3.2-vision:latest": "Llama 3.2"
    default: model
    }
}

// MARK: - Session Detail View

struct SessionChatView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SpeechRecognizer.self) private var speechRecognizer

    let session: ConversationSession
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var inputMode: InputMode = .text
    @State private var hasConnectionError = false

    enum InputMode {
        case text
        case voice
    }

    private var isCurrentSession: Bool {
        self.session.id == self.agent.currentSession?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SessionChatHeader(
                session: self.session,
                isActive: self.isCurrentSession && self.agent.isProcessing)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(self.session.messages) { message in
                            DetailedMessageRow(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom).combined(with: .opacity),
                                    removal: .opacity))
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.8),
                                    value: self.session.messages.count)
                        }

                        // Show progress indicator for active session
                        if self.isCurrentSession, self.agent.isProcessing {
                            ProgressIndicatorView(agent: self.agent)
                                .id("progress")
                                .padding(.top, 8)
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom).combined(with: .opacity),
                                    removal: .opacity))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: self.agent.isProcessing)
                        }
                    }
                    .padding()
                }
                .onChange(of: self.session.messages.count) { _, _ in
                    // Auto-scroll to bottom on new messages
                    if let lastMessage = session.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area (only for current session)
            if self.isCurrentSession {
                Divider()

                // Connection error banner
                if self.hasConnectionError {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)

                        Text("Connection lost. Messages will be queued.")
                            .font(.caption)
                            .foregroundColor(.red)

                        Spacer()

                        Button("Retry") {
                            // Clear error state and retry connection
                            self.hasConnectionError = false

                            // Retry the last failed task if available
                            if let lastTask = agent.lastTask {
                                Task {
                                    self.isProcessing = true
                                    defer { isProcessing = false }

                                    // Re-execute the last task
                                    do {
                                        try await self.agent.executeTask(lastTask)
                                        self.hasConnectionError = false
                                    } catch {
                                        // Error persists
                                        self.hasConnectionError = true
                                    }
                                }
                            }
                        }
                        .buttonStyle(.link)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))

                    Divider()
                }

                if self.inputMode == .text {
                    self.textInputArea
                } else {
                    self.voiceInputArea
                }
            }
        }
    }

    private var textInputArea: some View {
        HStack(spacing: 8) {
            TextField(self.placeholderText, text: self.$inputText)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit {
                    self.submitInput()
                }

            Button(action: { self.inputMode = .voice }) {
                Image(systemName: "mic")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if self.agent.isProcessing, self.isCurrentSession {
                // Show stop button during execution
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

            Button(action: self.submitInput) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(self.inputText.isEmpty ? .secondary : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(self.inputText.isEmpty)
        }
        .padding(12)
    }

    private var placeholderText: String {
        if self.agent.isProcessing, self.isCurrentSession {
            "Ask a follow-up question..."
        } else {
            "Ask Peekaboo..."
        }
    }

    private var voiceInputArea: some View {
        VStack(spacing: 12) {
            if self.speechRecognizer.isListening {
                Text(self.speechRecognizer.transcript.isEmpty ? "Listening..." : self.speechRecognizer.transcript)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            HStack {
                Button(action: { self.inputMode = .text }) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: self.toggleVoiceRecording) {
                    Image(systemName: self.speechRecognizer.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(self.speechRecognizer.isListening ? .red : .accentColor)
                }
                .buttonStyle(.plain)

                Spacer()

                // Placeholder to balance the layout
                Color.clear
                    .frame(width: 30, height: 30)
            }
        }
        .padding()
        .frame(height: 100)
    }

    private func submitInput() {
        let trimmedInput = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        // Clear input immediately
        self.inputText = ""

        if self.agent.isProcessing, self.isCurrentSession {
            // During execution, just add as a follow-up message
            self.sessionStore.addMessage(
                ConversationMessage(role: .user, content: trimmedInput),
                to: self.session)

            // Start a new execution with the follow-up
            Task {
                do {
                    try await self.agent.executeTask(trimmedInput)
                } catch {
                    print("Failed to execute follow-up: \(error)")
                }
            }
        } else {
            // Normal execution
            Task {
                self.isProcessing = true
                defer { isProcessing = false }

                do {
                    try await self.agent.executeTask(trimmedInput)
                } catch {
                    // Check if it's a connection error
                    let errorMessage = error.localizedDescription
                    if errorMessage.contains("network") || errorMessage.contains("connection") {
                        self.hasConnectionError = true
                    }
                    // Error is already added to session by agent
                    print("Task error: \(errorMessage)")
                }
            }
        }
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
                    print("Speech recognition error: \(error)")
                }
            }
        }
    }
}

// MARK: - Session Detail Header

struct SessionChatHeader: View {
    let session: ConversationSession
    let isActive: Bool

    @Environment(PeekabooAgent.self) private var agent
    @State private var showDebugInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Main header content
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(self.session.title)
                            .font(.headline)

                        if self.isActive {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }

                    HStack(spacing: 4) {
                        if !self.session.modelName.isEmpty {
                            Text(formatModelName(self.session.modelName))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if self.isActive, self.agent.isProcessing {
                            Text("•")
                                .foregroundColor(.secondary)

                            // Show current tool or thinking status
                            if let currentTool = agent.currentTool {
                                Text("\(PeekabooAgent.iconForTool(currentTool)) \(currentTool)")
                                    .font(.caption)
                                    .foregroundColor(.blue)

                                if let args = agent.currentToolArgs, !args.isEmpty {
                                    Text(args)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            } else if self.agent.isThinking {
                                AnimatedThinkingIndicator()
                            } else if !self.agent.currentTask.isEmpty {
                                Text(self.agent.currentTask)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()

                // Debug toggle
                Button(action: { self.showDebugInfo.toggle() }) {
                    Label("Debug", systemImage: self.showDebugInfo ? "info.circle.fill" : "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if self.isActive, self.agent.isProcessing {
                    Button(action: {
                        self.agent.cancelCurrentTask()
                    }) {
                        Label("Cancel", systemImage: "stop.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }

                Text(self.session.startTime, format: .dateTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(self.showDebugInfo ? Color.clear : Color(NSColor.windowBackgroundColor))

            if self.showDebugInfo {
                Divider()
                    .padding(.horizontal)

                SessionDebugInfo(session: self.session, isActive: self.isActive)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .background(
            self.showDebugInfo ?
                // Extended white background with subtle material effect
                ZStack {
                    Color(NSColor.windowBackgroundColor)
                    VisualEffectView(material: .headerView, blendingMode: .withinWindow)
                        .opacity(0.5)
                } : nil)
    }
}

// MARK: - Empty Session View

struct EmptySessionView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        VStack(spacing: 20) {
            GhostImageView(state: .idle, size: CGSize(width: 80, height: 80))
                .opacity(0.5)

            Text("No Session Selected")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select a session from the sidebar or create a new one")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { _ = self.sessionStore.createSession(title: "New Session") }) {
                Label("New Session", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Detailed Message Row for Main Window

struct DetailedMessageRow: View {
    let message: ConversationMessage
    @State private var isExpanded = false
    @State private var showingImageInspector = false
    @State private var selectedImage: NSImage?
    @State private var appeared = false
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Message header
            HStack(alignment: .top, spacing: 12) {
                // Avatar or Tool Icon
                if self.isToolMessage {
                    // For tool messages, show the tool icon in the avatar position
                    let toolName = self.extractToolName(from: self.message.content)
                    let toolStatus = self.determineToolStatus(from: self.message)

                    EnhancedToolIcon(
                        toolName: toolName,
                        status: toolStatus)
                        .font(.system(size: 20)) // Larger icon
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                } else if self.isThinkingMessage {
                    // Special thinking icon with animation
                    ZStack {
                        Image(systemName: "brain")
                            .font(.title3)
                            .foregroundColor(.purple)
                            .frame(width: 32, height: 32)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(Circle())

                        // Animated thinking indicator
                        Circle()
                            .stroke(Color.purple, lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(360))
                            .animation(
                                Animation.linear(duration: 2)
                                    .repeatForever(autoreverses: false),
                                value: true)
                    }
                } else {
                    ZStack {
                        Image(systemName: self.iconName)
                            .font(.title3)
                            .foregroundColor(self.iconColor)
                            .frame(width: 32, height: 32)
                            .background(self.iconColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(self.roleTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if self.isErrorMessage {
                            Label("Error", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if self.isWarningMessage {
                            Label("Cancelled", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        Text(self.message.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Retry button for error messages
                        if self.isErrorMessage, !self.agent.isProcessing {
                            Button(action: self.retryLastTask) {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Retry the failed task")
                        }

                        if !self.message.toolCalls.isEmpty {
                            Button(action: { self.isExpanded.toggle() }) {
                                Label(
                                    "\(self.message.toolCalls.count) tools",
                                    systemImage: self
                                        .isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if self.isThinkingMessage {
                        // Show the actual thinking content, removing the 🤔 emoji
                        Text(self.message.content.replacingOccurrences(of: "🤔 ", with: ""))
                            .font(.system(.body))
                            .foregroundColor(.purple)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if self.isErrorMessage {
                        Text(self.message.content)
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if self.isWarningMessage {
                        Text(self.message.content)
                            .foregroundColor(.orange)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if self.isToolMessage {
                        // Show tool execution details without inline icon (icon is in avatar position)
                        if let toolCall = message.toolCalls.first {
                            let isRunning = toolCall.result == "Running..."
                            let content = self.message.content
                                .replacingOccurrences(of: "🔧 ", with: "")
                                .replacingOccurrences(of: "✅ ", with: "")
                                .replacingOccurrences(of: "❌ ", with: "")

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(content)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    if !isRunning, toolCall.result != "Running..." {
                                        // Show result summary if available
                                        let toolName = self.extractToolName(from: self.message.content)
                                        if let resultSummary = ToolFormatter.toolResultSummary(
                                            toolName: toolName,
                                            result: toolCall.result)
                                        {
                                            Text(resultSummary)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                if isRunning {
                                    TimeIntervalText(startTime: self.message.timestamp)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .textSelection(.enabled)
                        } else {
                            Text(self.message.content
                                .replacingOccurrences(of: "🔧 ", with: "")
                                .replacingOccurrences(of: "✅ ", with: "")
                                .replacingOccurrences(of: "❌ ", with: ""))
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                    } else if self.message.role == .assistant {
                        // Render assistant messages as Markdown
                        if let attributedString = try? AttributedString(
                            markdown: message.content,
                            options: AttributedString.MarkdownParsingOptions(
                                allowsExtendedAttributes: true,
                                interpretedSyntax: .inlineOnlyPreservingWhitespace))
                        {
                            Text(attributedString)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(self.message.content)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(self.message.content)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Show active tool executions
                    if self.message.role == .assistant, self.hasRunningTools {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Executing tools...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            // Expanded tool calls - show details directly without nested expansion
            if self.isExpanded, !self.message.toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(self.message.toolCalls) { toolCall in
                        VStack(alignment: .leading, spacing: 8) {
                            // Arguments
                            if !toolCall.arguments.isEmpty, toolCall.arguments != "{}" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Arguments")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(self.formatJSON(toolCall.arguments))
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(8)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(4)
                                }
                            }

                            // Result
                            if !toolCall.result.isEmpty, toolCall.result != "Running..." {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Result")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    // Check if result contains image data
                                    if toolCall.name.contains("image") || toolCall.name.contains("screenshot"),
                                       let imageData = extractImageData(from: toolCall.result),
                                       let image = NSImage(data: imageData)
                                    {
                                        Button(action: {
                                            self.selectedImage = image
                                            self.showingImageInspector = true
                                        }) {
                                            Image(nsImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxHeight: 200)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Click to inspect image")
                                    } else {
                                        Text(toolCall.result)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .lineLimit(10)
                                            .padding(8)
                                            .background(Color(NSColor.textBackgroundColor))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 44)
            }
        }
        .padding()
        .background(self.backgroundForMessage)
        .cornerRadius(8)
        .scaleEffect(self.appeared ? 1 : 0.95)
        .opacity(self.appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.appeared = true
            }
        }
        .sheet(isPresented: self.$showingImageInspector) {
            if let image = selectedImage {
                ImageInspectorView(image: image)
            }
        }
    }

    private var isThinkingMessage: Bool {
        self.message.role == .system && self.message.content.contains("🤔")
    }

    private var isErrorMessage: Bool {
        self.message.role == .system && self.message.content.contains("❌")
    }

    private var isWarningMessage: Bool {
        self.message.role == .system && self.message.content.contains("⚠️")
    }

    private var isToolMessage: Bool {
        self.message
            .role == .system &&
            (self.message.content.contains("🔧") || self.message.content.contains("✅") || self.message.content
                .contains("❌"))
    }

    private var hasRunningTools: Bool {
        self.message.toolCalls.contains { $0.result == "Running..." }
    }

    private var backgroundForMessage: Color {
        if self.isErrorMessage {
            Color.red.opacity(0.1)
        } else if self.isWarningMessage {
            Color.orange.opacity(0.1)
        } else if self.isThinkingMessage {
            Color.purple.opacity(0.05)
        } else if self.isToolMessage {
            Color.blue.opacity(0.05)
        } else {
            Color(NSColor.controlBackgroundColor).opacity(0.3)
        }
    }

    private var iconName: String {
        switch self.message.role {
        case .user: "person.fill"
        case .assistant: "sparkles"
        case .system: "gear"
        }
    }

    private var iconColor: Color {
        if self.isToolMessage {
            return .purple
        }
        switch self.message.role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .orange
        }
    }

    private var roleTitle: String {
        switch self.message.role {
        case .user: "User"
        case .assistant: "Assistant"
        case .system: "System"
        }
    }

    private func extractToolName(from content: String) -> String {
        // Format is "🔧 toolname: args" or "✅ toolname: args" or "❌ toolname: args"
        let cleaned = content
            .replacingOccurrences(of: "🔧 ", with: "")
            .replacingOccurrences(of: "✅ ", with: "")
            .replacingOccurrences(of: "❌ ", with: "")

        if let colonIndex = cleaned.firstIndex(of: ":") {
            return String(cleaned[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    private func determineToolStatus(from message: ConversationMessage) -> ToolExecutionStatus {
        // First check if we have a tool call with a result
        if let toolCall = message.toolCalls.first {
            if toolCall.result == "Running..." {
                return .running
            }
            // If there's a non-empty result, it's completed (unless it contains error indicators)
            if !toolCall.result.isEmpty {
                if message.content.contains("❌") {
                    return .failed
                } else if message.content.contains("⚠️") {
                    return .cancelled
                } else {
                    return .completed
                }
            }
        }

        // Check the agent's tool execution history for the actual status
        let toolName = self.extractToolName(from: message.content)
        if !toolName.isEmpty {
            // Find the most recent execution of this tool
            if let execution = agent.toolExecutionHistory.last(where: { $0.toolName == toolName }) {
                return execution.status
            }
        }

        // Fallback to checking message content for status indicators
        if message.content.contains("✅") {
            return .completed
        } else if message.content.contains("❌") {
            return .failed
        } else if message.content.contains("⚠️") {
            return .cancelled
        }

        // Default to running for tool messages without clear status
        return .running
    }

    private func formatJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let formattedData = try? JSONSerialization.data(
                  withJSONObject: jsonObject,
                  options: [.prettyPrinted, .sortedKeys]),
              let formattedString = String(data: formattedData, encoding: .utf8)
        else {
            return json
        }
        return formattedString
    }

    private func extractImageData(from result: String) -> Data? {
        // Try to extract base64 image data from result
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let screenshotData = json["screenshot_data"] as? String,
           let imageData = Data(base64Encoded: screenshotData)
        {
            return imageData
        }
        return nil
    }

    private func retryLastTask() {
        // Find the session containing this message
        guard let session = sessionStore.sessions.first(where: { session in
            session.messages.contains(where: { $0.id == message.id })
        }) else { return }

        // Find the error message index
        guard let errorIndex = session.messages.firstIndex(where: { $0.id == message.id }),
              errorIndex > 0 else { return }

        // Look backwards for the last user message
        for i in stride(from: errorIndex - 1, through: 0, by: -1) {
            let msg = session.messages[i]
            if msg.role == .user {
                // Make this the current session if it isn't already
                if self.sessionStore.currentSession?.id != session.id {
                    self.sessionStore.selectSession(session)
                }

                // Re-execute the last user task
                Task {
                    do {
                        try await self.agent.executeTask(msg.content)
                    } catch {
                        print("Retry failed: \(error)")
                    }
                }
                break
            }
        }
    }
}

// MARK: - Detailed Tool Call View

struct DetailedToolCallView: View {
    let toolCall: ConversationToolCall
    let onImageTap: (NSImage) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tool header
            HStack {
                AnimatedToolIcon(
                    toolName: self.toolCall.name,
                    isRunning: false)

                Text(self.toolCall.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(action: { self.isExpanded.toggle() }) {
                    Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if self.isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Arguments
                    if !self.toolCall.arguments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arguments")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(self.formatJSON(self.toolCall.arguments))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)
                        }
                    }

                    // Result
                    if !self.toolCall.result.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Result")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Check if result contains image data
                            if self.toolCall.name.contains("image") || self.toolCall.name.contains("screenshot"),
                               let imageData = extractImageData(from: toolCall.result),
                               let image = NSImage(data: imageData)
                            {
                                Button(action: { self.onImageTap(image) }) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Click to inspect image")

                            } else {
                                Text(self.toolCall.result)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .lineLimit(10)
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private func formatJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8)
        else {
            return string
        }
        return prettyString
    }

    private func extractImageData(from result: String) -> Data? {
        // This is a placeholder - implement based on how images are returned
        // Could be base64 encoded, file path, etc.
        nil
    }
}

// MARK: - Session Debug Info

struct SessionDebugInfo: View {
    let session: ConversationSession
    let isActive: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Left group: Session info
            HStack(spacing: 16) {
                // Session ID (shortened)
                HStack(spacing: 4) {
                    Image(systemName: "number.square.fill")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))

                    Text(String(self.session.id.prefix(8)))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .help(self.session.id) // Full ID on hover
                }

                Divider()
                    .frame(height: 12)

                // Messages & Tools combined
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "message.fill")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                        Text("\(self.session.messages.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                        Text("\(self.session.messages.flatMap(\.toolCalls).count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            Spacer()

            // Right group: Duration
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))

                SessionDurationText(startTime: self.session.startTime)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Duration Text

struct SessionDurationText: View {
    let startTime: Date
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(self.formatDuration(self.currentTime.timeIntervalSince(self.startTime)))
            .onReceive(self.timer) { _ in
                self.currentTime = Date()
            }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        }
    }
}

// MARK: - Image Inspector View

struct ImageInspectorView: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss
    @State private var zoomLevel: CGFloat = 1.0
    @State private var imageOffset = CGSize.zero
    @State private var showPixelGrid = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Image Inspector")
                    .font(.headline)

                Spacer()

                Text("\(Int(self.image.size.width))×\(Int(self.image.size.height))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Done") {
                    self.dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Image viewer
            GeometryReader { geometry in
                Image(nsImage: self.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(self.zoomLevel)
                    .offset(self.imageOffset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color.black)
                    .onTapGesture(count: 2) {
                        withAnimation {
                            self.zoomLevel = self.zoomLevel == 1.0 ? 2.0 : 1.0
                            self.imageOffset = .zero
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                self.imageOffset = value.translation
                            })
            }

            // Controls
            HStack {
                Button(action: { self.zoomLevel = max(0.25, self.zoomLevel - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                }

                Slider(value: self.$zoomLevel, in: 0.25...4.0)
                    .frame(width: 200)

                Button(action: { self.zoomLevel = min(4.0, self.zoomLevel + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                }

                Divider()
                    .frame(height: 20)

                Toggle("Pixel Grid", isOn: self.$showPixelGrid)
                    .toggleStyle(.checkbox)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 800, minHeight: 400, idealHeight: 600)
    }
}

// MARK: - Animated Thinking Components

struct SessionAnimatedThinkingDots: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .foregroundStyle(.secondary)
            .font(.title3.bold())
            .symbolEffect(
                .variableColor
                    .iterative
                    .hideInactiveLayers)
    }
}

struct AnimatedThinkingIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Thinking")
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: "ellipsis")
                .foregroundStyle(.blue)
                .font(.caption.bold())
                .symbolEffect(
                    .variableColor
                        .iterative
                        .hideInactiveLayers)
        }
    }
}

// MARK: - Progress Indicator View

struct ProgressIndicatorView: View {
    @Environment(PeekabooAgent.self) private var agent
    @State private var animationPhase = 0.0

    init(agent: PeekabooAgent) {
        // Just for interface consistency
    }

    var body: some View {
        HStack(spacing: 12) {
            // Animated icon
            if let currentTool = agent.currentTool {
                Text(PeekabooAgent.iconForTool(currentTool))
                    .font(.title2)
                    .scaleEffect(1 + sin(self.animationPhase) * 0.1)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: self.animationPhase)
            } else if self.agent.isThinking {
                SessionAnimatedThinkingDots()
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Primary status
                if let currentTool = agent.currentTool {
                    HStack(spacing: 4) {
                        Text(currentTool)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        if let args = agent.currentToolArgs, !args.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(args)
                                .font(.system(.body))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else if self.agent.isThinking {
                    AnimatedThinkingIndicator()
                        .font(.system(.body, design: .rounded))
                } else {
                    Text("Processing...")
                        .font(.system(.body))
                        .foregroundColor(.secondary)
                }

                // Task context
                if !self.agent.currentTask.isEmpty, self.agent.currentTool == nil {
                    Text(self.agent.currentTask)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .onAppear {
            self.animationPhase = 1
        }
    }
}

#Preview {
    let settings = PeekabooSettings()
    SessionMainWindow()
        .environment(settings)
        .environment(SessionStore())
        .environment(PeekabooAgent(settings: settings, sessionStore: SessionStore()))
        .environment(SpeechRecognizer(settings: settings))
        .environment(Permissions())
}
