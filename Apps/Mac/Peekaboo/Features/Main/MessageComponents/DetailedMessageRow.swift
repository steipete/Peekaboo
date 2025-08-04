import SwiftUI
import PeekabooCore

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

                    MessageContentView(
                        message: message,
                        isThinkingMessage: isThinkingMessage,
                        isErrorMessage: isErrorMessage,
                        isWarningMessage: isWarningMessage,
                        isToolMessage: isToolMessage,
                        extractToolName: extractToolName
                    )

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
                ExpandedToolCallsView(
                    toolCalls: message.toolCalls,
                    onImageTap: { image in
                        self.selectedImage = image
                        self.showingImageInspector = true
                    }
                )
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

    // MARK: - Message Type Detection

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

    // MARK: - Message Styling

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

    // MARK: - Tool Utilities

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