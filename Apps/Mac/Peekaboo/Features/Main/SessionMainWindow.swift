import SwiftUI
import UniformTypeIdentifiers
import PeekabooCore

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
            // Sidebar with session list
            SessionSidebar(
                selectedSessionId: $selectedSessionId,
                searchText: $searchText,
                onCreateNewSession: createNewSession
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            // Detail view
            if let sessionId = selectedSessionId,
               let session = sessionStore.sessions.first(where: { $0.id == sessionId }) {
                SessionChatView(session: session)
                    .toolbar(removing: .sidebarToggle)
            } else if let currentSession = sessionStore.currentSession {
                SessionChatView(session: currentSession)
                    .toolbar(removing: .sidebarToggle)
            } else {
                EmptySessionView(onCreateNewSession: createNewSession)
                    .toolbar(removing: .sidebarToggle)
            }
        }
        .navigationTitle("Peekaboo Sessions")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .onAppear {
            // Select current session by default
            if selectedSessionId == nil {
                selectedSessionId = sessionStore.currentSession?.id
            }
        }
        .onChange(of: sessionStore.currentSession?.id) { _, newId in
            // Auto-select new current session
            if let newId = newId {
                selectedSessionId = newId
            }
        }
        // Removed sheet - creating sessions directly
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?
            .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    private func createNewSession() {
        let newSession = sessionStore.createSession(title: "New Session")
        selectedSessionId = newSession.id
    }
}

// MARK: - Session Sidebar

struct SessionSidebar: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PeekabooAgent.self) private var agent
    
    @Binding var selectedSessionId: String?
    @Binding var searchText: String
    var onCreateNewSession: () -> Void
    
    private var filteredSessions: [Session] {
        if searchText.isEmpty {
            return sessionStore.sessions
        } else {
            return sessionStore.sessions.filter { session in
                session.title.localizedCaseInsensitiveContains(searchText) ||
                session.summary.localizedCaseInsensitiveContains(searchText) ||
                session.messages.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
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
                
                Button(action: onCreateNewSession) {
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
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
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
            List(filteredSessions, selection: $selectedSessionId) { session in
                SessionRow(
                    session: session,
                    isActive: agent.currentSession?.id == session.id,
                    onDelete: { deleteSession(session) }
                )
                .tag(session.id)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteSession(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .contextMenu {
                    Button("Delete") {
                        deleteSession(session)
                    }
                    Button("Duplicate") {
                        duplicateSession(session)
                    }
                    Divider()
                    Button("Export...") {
                        exportSession(session)
                    }
                }
            }
            .listStyle(.sidebar)
            .onDeleteCommand {
                // Delete the currently selected session
                if let selectedId = selectedSessionId,
                   let session = sessionStore.sessions.first(where: { $0.id == selectedId }),
                   session.id != agent.currentSession?.id {
                    deleteSession(session)
                }
            }
        }
    }
    
    private func deleteSession(_ session: Session) {
        // Don't delete active session
        guard session.id != agent.currentSession?.id else { return }
        
        sessionStore.sessions.removeAll { $0.id == session.id }
        Task {
            try? await sessionStore.saveSessions()
        }
        
        if selectedSessionId == session.id {
            selectedSessionId = nil
        }
    }
    
    private func duplicateSession(_ session: Session) {
        var newSession = Session(title: "\(session.title) (Copy)")
        newSession.messages = session.messages
        newSession.summary = session.summary
        
        sessionStore.sessions.insert(newSession, at: 0)
        Task {
            try? await sessionStore.saveSessions()
        }
        
        selectedSessionId = newSession.id
    }
    
    private func exportSession(_ session: Session) {
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
    let session: Session
    let isActive: Bool
    let onDelete: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title)
                    .font(.body)
                    .fontWeight(isActive ? .semibold : .regular)
                    .lineLimit(1)
                
                if isActive {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                        .symbolEffect(.pulse, options: .repeating)
                }
                
                Spacer()
                
                // Delete button on hover
                if isHovering && !isActive {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete session")
                }
            }
            
            HStack {
                Text(session.startTime, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !session.messages.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("\(session.messages.count) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !session.modelName.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(formatModelName(session.modelName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !session.summary.isEmpty {
                Text(session.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Helper Functions

private func formatModelName(_ model: String) -> String {
    // Shorten common model names for display
    switch model {
    case "gpt-4.1": return "GPT-4.1"
    case "gpt-4.1-mini": return "GPT-4.1 mini"
    case "gpt-4o": return "GPT-4o"
    case "gpt-4o-mini": return "GPT-4o mini"
    case "o3": return "o3"
    case "o3-pro": return "o3 pro"
    case "o4-mini": return "o4-mini"
    case "claude-opus-4-20250514": return "Claude Opus 4"
    case "claude-sonnet-4-20250514": return "Claude Sonnet 4"
    case "claude-3-5-haiku": return "Claude 3.5 Haiku"
    case "claude-3-5-sonnet": return "Claude 3.5 Sonnet"
    case "llava:latest": return "LLaVA"
    case "llama3.2-vision:latest": return "Llama 3.2"
    default: return model
    }
}

// MARK: - Session Detail View

struct SessionChatView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SpeechRecognizer.self) private var speechRecognizer
    
    let session: Session
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var inputMode: InputMode = .text
    @State private var hasConnectionError = false
    
    enum InputMode {
        case text
        case voice
    }
    
    private var isCurrentSession: Bool {
        session.id == agent.currentSession?.id
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SessionChatHeader(
                session: session,
                isActive: isCurrentSession && agent.isProcessing
            )
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(session.messages) { message in
                            DetailedMessageRow(message: message)
                                .id(message.id)
                        }
                        
                        // Show progress indicator for active session
                        if isCurrentSession && agent.isProcessing {
                            ProgressIndicatorView(agent: agent)
                                .id("progress")
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                }
                .onChange(of: session.messages.count) { _, _ in
                    // Auto-scroll to bottom on new messages
                    if let lastMessage = session.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area (only for current session)
            if isCurrentSession {
                Divider()
                
                // Connection error banner
                if hasConnectionError {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)
                        
                        Text("Connection lost. Messages will be queued.")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Retry") {
                            // Clear error state and retry connection
                            hasConnectionError = false
                            
                            // Retry the last failed task if available
                            if !agent.currentTask.isEmpty {
                                let lastTask = agent.currentTask
                                Task {
                                    isProcessing = true
                                    defer { isProcessing = false }
                                    
                                    // Re-execute the last task
                                    do {
                                        try await agent.executeTask(lastTask)
                                        hasConnectionError = false
                                    } catch {
                                        // Error persists
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
                
                if inputMode == .text {
                    textInputArea
                } else {
                    voiceInputArea
                }
            }
        }
    }
    
    private var textInputArea: some View {
        HStack(spacing: 8) {
            TextField(placeholderText, text: $inputText)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit {
                    submitInput()
                }
            
            Button(action: { inputMode = .voice }) {
                Image(systemName: "mic")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            if agent.isProcessing && isCurrentSession {
                // Show stop button during execution
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
            
            Button(action: submitInput) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(12)
    }
    
    private var placeholderText: String {
        if agent.isProcessing && isCurrentSession {
            return "Ask a follow-up question..."
        } else {
            return "Ask Peekaboo..."
        }
    }
    
    private var voiceInputArea: some View {
        VStack(spacing: 12) {
            if speechRecognizer.isListening {
                Text(speechRecognizer.transcript.isEmpty ? "Listening..." : speechRecognizer.transcript)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            
            HStack {
                Button(action: { inputMode = .text }) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: toggleVoiceRecording) {
                    Image(systemName: speechRecognizer.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(speechRecognizer.isListening ? .red : .accentColor)
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
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        // Clear input immediately
        inputText = ""
        
        if agent.isProcessing && isCurrentSession {
            // During execution, just add as a follow-up message
            sessionStore.addMessage(
                SessionMessage(role: .user, content: trimmedInput),
                to: session
            )
            
            // If agent is executing, queue the message for later
            if agent.isProcessing {
                // Queue the message
                agent.queueMessage(trimmedInput)
            } else {
                // Start a new execution with the follow-up
                Task {
                    do {
                        try await agent.executeTask(trimmedInput)
                    } catch {
                        print("Failed to execute follow-up: \(error)")
                    }
                }
            }
        } else {
            // Normal execution
            Task {
                isProcessing = true
                defer { isProcessing = false }
                
                do {
                    try await agent.executeTask(trimmedInput)
                } catch {
                    // Check if it's a connection error
                    let errorMessage = error.localizedDescription
                    if errorMessage.contains("network") || errorMessage.contains("connection") {
                        hasConnectionError = true
                    }
                    // Error is already added to session by agent
                    print("Task error: \(errorMessage)")
                }
            }
        }
    }
    
    private func toggleVoiceRecording() {
        if speechRecognizer.isListening {
            // Stop and submit
            speechRecognizer.stopListening()
            
            let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                inputText = transcript
                submitInput()
            }
        } else {
            // Start listening
            Task {
                do {
                    try speechRecognizer.startListening()
                } catch {
                    print("Speech recognition error: \(error)")
                }
            }
        }
    }
}

// MARK: - Session Detail Header

struct SessionChatHeader: View {
    let session: Session
    let isActive: Bool
    
    @Environment(PeekabooAgent.self) private var agent
    @State private var showDebugInfo = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.title)
                            .font(.headline)
                        
                        if isActive {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        if !session.modelName.isEmpty {
                            Text(formatModelName(session.modelName))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if isActive && agent.isProcessing {
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
                            } else if agent.isThinking {
                                Text("💭 Thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .opacity(0.8)
                            } else if !agent.currentTask.isEmpty {
                                Text(agent.currentTask)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Debug toggle
                Button(action: { showDebugInfo.toggle() }) {
                    Label("Debug", systemImage: showDebugInfo ? "info.circle.fill" : "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                if isActive && agent.isProcessing {
                    Button(action: { 
                        agent.cancelCurrentTask()
                    }) {
                        Label("Cancel", systemImage: "stop.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(session.startTime, format: .dateTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            if showDebugInfo {
                Divider()
                SessionDebugInfo(session: session)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}

// MARK: - Empty Session View

struct EmptySessionView: View {
    var onCreateNewSession: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image("ghost.idle")
                .resizable()
                .frame(width: 80, height: 80)
                .opacity(0.5)
            
            Text("No Session Selected")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Select a session from the sidebar or create a new one")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onCreateNewSession) {
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
    let message: SessionMessage
    @State private var isExpanded = false
    @State private var showingImageInspector = false
    @State private var selectedImage: NSImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Message header
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                ZStack {
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                        .background(iconColor.opacity(0.1))
                        .clipShape(Circle())
                    
                    // Animated thinking indicator
                    if isThinkingMessage {
                        Circle()
                            .stroke(Color.purple, lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(360))
                            .animation(
                                Animation.linear(duration: 2)
                                    .repeatForever(autoreverses: false),
                                value: true
                            )
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(roleTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if isErrorMessage {
                            Label("Error", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if isWarningMessage {
                            Label("Cancelled", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Text(message.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !message.toolCalls.isEmpty {
                            Button(action: { isExpanded.toggle() }) {
                                Label("\(message.toolCalls.count) tools", 
                                      systemImage: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if isThinkingMessage {
                        Text(message.content.replacingOccurrences(of: "🤔 ", with: ""))
                            .italic()
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if isErrorMessage {
                        Text(message.content)
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if isWarningMessage {
                        Text(message.content)
                            .foregroundColor(.orange)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if isToolMessage {
                        HStack(spacing: 8) {
                            // Show dynamic status based on tool execution state
                            if let toolCall = message.toolCalls.first {
                                let isRunning = toolCall.result == "Running..."
                                let statusIcon = isRunning ? "🔧" : (toolCall.result.contains("error") || toolCall.result.contains("failed") ? "❌" : "✅")
                                let statusText = isRunning ? message.content : message.content.replacingOccurrences(of: "🔧", with: statusIcon)
                                
                                Text(statusText)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                if isRunning {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.7)
                                }
                            } else {
                                Text(message.content)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                        }
                        .textSelection(.enabled)
                    } else {
                        Text(message.content)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Show active tool executions
                    if message.role == .assistant && hasRunningTools {
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
            
            // Expanded tool calls
            if isExpanded && !message.toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(message.toolCalls) { toolCall in
                        DetailedToolCallView(toolCall: toolCall) { image in
                            selectedImage = image
                            showingImageInspector = true
                        }
                    }
                }
                .padding(.leading, 44)
            }
        }
        .padding()
        .background(backgroundForMessage)
        .cornerRadius(8)
        .sheet(isPresented: $showingImageInspector) {
            if let image = selectedImage {
                ImageInspectorView(image: image)
            }
        }
    }
    
    private var isThinkingMessage: Bool {
        message.role == .system && message.content.contains("🤔")
    }
    
    private var isErrorMessage: Bool {
        message.role == .system && message.content.contains("❌")
    }
    
    private var isWarningMessage: Bool {
        message.role == .system && message.content.contains("⚠️")
    }
    
    private var isToolMessage: Bool {
        message.role == .system && (message.content.contains("🔧") || message.content.contains("✅") || message.content.contains("❌"))
    }
    
    private var hasRunningTools: Bool {
        message.toolCalls.contains { $0.result == "Running..." }
    }
    
    private var backgroundForMessage: Color {
        if isErrorMessage {
            return Color.red.opacity(0.1)
        } else if isWarningMessage {
            return Color.orange.opacity(0.1)
        } else if isThinkingMessage {
            return Color.purple.opacity(0.05)
        } else if isToolMessage {
            return Color.blue.opacity(0.05)
        } else {
            return Color(NSColor.controlBackgroundColor).opacity(0.3)
        }
    }
    
    private var iconName: String {
        if isToolMessage {
            return "wrench.and.screwdriver.fill"
        }
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        case .system: return "gear"
        }
    }
    
    private var iconColor: Color {
        if isToolMessage {
            return .purple
        }
        switch message.role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .orange
        }
    }
    
    private var roleTitle: String {
        switch message.role {
        case .user: return "User"
        case .assistant: return "Assistant"
        case .system: return "System"
        }
    }
}

// MARK: - Detailed Tool Call View

struct DetailedToolCallView: View {
    let toolCall: ToolCall
    let onImageTap: (NSImage) -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tool header
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                Text(toolCall.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Arguments
                    if !toolCall.arguments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arguments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatJSON(toolCall.arguments))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Result
                    if !toolCall.result.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Result")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Check if result contains image data
                            if toolCall.name.contains("image") || toolCall.name.contains("screenshot"),
                               let imageData = extractImageData(from: toolCall.result),
                               let image = NSImage(data: imageData) {
                                
                                Button(action: { onImageTap(image) }) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
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
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private func formatJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return string
        }
        return prettyString
    }
    
    private func extractImageData(from result: String) -> Data? {
        // This is a placeholder - implement based on how images are returned
        // Could be base64 encoded, file path, etc.
        return nil
    }
}

// MARK: - Session Debug Info

struct SessionDebugInfo: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Session ID", systemImage: "number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(session.id)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            
            HStack {
                Label("Messages", systemImage: "message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(session.messages.count)")
                    .font(.caption)
            }
            
            HStack {
                Label("Tool Calls", systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(session.messages.flatMap { $0.toolCalls }.count)")
                    .font(.caption)
            }
            
            HStack {
                Label("Duration", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastMessage = session.messages.last {
                    Text(lastMessage.timestamp, style: .relative)
                        .font(.caption)
                } else {
                    Text("No messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
                
                Text("\(Int(image.size.width))×\(Int(image.size.height))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Image viewer
            GeometryReader { geometry in
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomLevel)
                    .offset(imageOffset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color.black)
                    .onTapGesture(count: 2) {
                        withAnimation {
                            zoomLevel = zoomLevel == 1.0 ? 2.0 : 1.0
                            imageOffset = .zero
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                imageOffset = value.translation
                            }
                    )
            }
            
            // Controls
            HStack {
                Button(action: { zoomLevel = max(0.25, zoomLevel - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                
                Slider(value: $zoomLevel, in: 0.25...4.0)
                    .frame(width: 200)
                
                Button(action: { zoomLevel = min(4.0, zoomLevel + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                
                Divider()
                    .frame(height: 20)
                
                Toggle("Pixel Grid", isOn: $showPixelGrid)
                    .toggleStyle(.checkbox)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 800, minHeight: 400, idealHeight: 600)
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
                    .scaleEffect(1 + sin(animationPhase) * 0.1)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animationPhase)
            } else if agent.isThinking {
                Text("💭")
                    .font(.title2)
                    .opacity(0.6 + sin(animationPhase) * 0.4)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animationPhase)
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
                } else if agent.isThinking {
                    Text("Thinking...")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text("Processing...")
                        .font(.system(.body))
                        .foregroundColor(.secondary)
                }
                
                // Task context
                if !agent.currentTask.isEmpty && agent.currentTool == nil {
                    Text(agent.currentTask)
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
            animationPhase = 1
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