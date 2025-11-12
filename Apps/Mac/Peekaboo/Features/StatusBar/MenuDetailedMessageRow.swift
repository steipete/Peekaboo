import PeekabooCore
import SwiftUI

/// Enhanced message row for menu bar with full agent flow visualization
struct MenuDetailedMessageRow: View {
    let message: ConversationMessage
    @State private var isExpanded = false
    @State private var showingImageInspector = false
    @State private var selectedImage: NSImage?
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore

    private let compactAvatarSize: CGFloat = 20
    private let compactSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: self.compactSpacing) {
            // Main message content
            HStack(alignment: .top, spacing: self.compactSpacing) {
                // Compact avatar or tool icon
                self.avatarView
                    .frame(width: self.compactAvatarSize, height: self.compactAvatarSize)

                // Message content
                VStack(alignment: .leading, spacing: 4) {
                    // Header line with role, time, and status
                    self.headerView

                    // Message content
                    self.contentView

                    // Tool execution summary (if applicable)
                    if self.isToolMessage, !self.message.toolCalls.isEmpty {
                        self.toolExecutionSummary
                    }
                }

                Spacer(minLength: 0)
            }

            // Expandable tool details
            if self.isExpanded, !self.message.toolCalls.isEmpty {
                self.toolDetailsView
                    .padding(.leading, self.compactAvatarSize + self.compactSpacing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(self.backgroundForMessage)
        .cornerRadius(6)
        .sheet(isPresented: self.$showingImageInspector) {
            if let image = selectedImage {
                ImageInspectorView(image: image)
            }
        }
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if self.isToolMessage {
            let toolName = self.extractToolName(from: self.message.content)
            let toolStatus = self.determineToolStatus(from: self.message)

            EnhancedToolIcon(
                toolName: toolName,
                status: toolStatus)
                .font(.system(size: 14))
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
        } else if self.isThinkingMessage {
            ZStack {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())

                // Subtle rotation animation
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(360))
                    .animation(
                        Animation.linear(duration: 3)
                            .repeatForever(autoreverses: false),
                        value: true)
            }
        } else {
            Image(systemName: self.iconName)
                .font(.caption)
                .foregroundColor(self.iconColor)
                .background(self.iconColor.opacity(0.1))
                .clipShape(Circle())
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 4) {
            // Role or tool name
            if self.isToolMessage {
                Text(self.extractToolName(from: self.message.content))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            } else {
                Text(self.roleTitle)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            // Status indicators
            if self.isErrorMessage {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            } else if self.isWarningMessage {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            // Time
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(self.message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            // Expand button for tool calls
            if !self.message.toolCalls.isEmpty {
                Button(action: { self.isExpanded.toggle() }, label: {
                    Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                })
                .buttonStyle(.plain)
                .help(self.isExpanded ? "Hide details" : "Show details")
            }

            // Retry button for errors
            if self.isErrorMessage, !self.agent.isProcessing {
                Button(action: self.retryLastTask, label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Color.red)
                        .cornerRadius(3)
                })
                .buttonStyle(.plain)
                .help("Retry task")
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if self.isThinkingMessage {
            HStack(spacing: 4) {
                Text(self.message.content.replacingOccurrences(
                    of: "\(AgentDisplayTokens.Status.planning) ",
                    with: ""))
                    .font(.caption)
                    .foregroundColor(.purple)
                    .italic()
                    .lineLimit(2)

                if #available(macOS 15.0, *) {
                    AnimatedThinkingDots()
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
        } else if self.isToolMessage {
            // Compact tool display
            if let toolCall = message.toolCalls.first {
                let isRunning = toolCall.result == "Running..."

                HStack(spacing: 4) {
                    Text(self.formatToolContent())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if isRunning {
                        TimeIntervalText(startTime: self.message.timestamp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(self.formatToolContent())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        } else if self.message.role == .assistant {
            // Markdown support for assistant messages
            if let attributed = try? AttributedString(
                markdown: self.message.content,
                options: AttributedString.MarkdownParsingOptions(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace))
            {
                Text(attributed)
                    .font(.caption)
                    .lineLimit(self.isExpanded ? nil : 3)
                    .textSelection(.enabled)
            } else {
                Text(self.message.content)
                    .font(.caption)
                    .lineLimit(self.isExpanded ? nil : 3)
                    .textSelection(.enabled)
            }
        } else {
            Text(self.message.content)
                .font(.caption)
                .foregroundColor(self.isErrorMessage ? .red : (self.isWarningMessage ? .orange : .primary))
                .lineLimit(self.isExpanded ? nil : 2)
                .textSelection(.enabled)
        }
    }

    // MARK: - Tool Execution Summary

    @ViewBuilder
    private var toolExecutionSummary: some View {
        if let toolCall = message.toolCalls.first,
           toolCall.result != "Running...",
           let toolName = message.toolCalls.first?.name,
           let resultSummary = ToolFormatter.toolResultSummary(toolName: toolName, result: toolCall.result)
        {
            Text(resultSummary)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Tool Details View

    @ViewBuilder
    private var toolDetailsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(self.message.toolCalls) { toolCall in
                VStack(alignment: .leading, spacing: 4) {
                    // Arguments (if not empty)
                    if !toolCall.arguments.isEmpty, toolCall.arguments != "{}" {
                        Text("Arguments:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(self.formatCompactJSON(toolCall.arguments))
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(3)
                    }

                    // Result (if available)
                    if !toolCall.result.isEmpty, toolCall.result != "Running..." {
                        Text("Result:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Check for image data
                        if toolCall.name.contains("image") || toolCall.name.contains("screenshot"),
                           let imageData = extractImageData(from: toolCall.result),
                           let image = NSImage(data: imageData)
                        {
                            Button(action: {
                                self.selectedImage = image
                                self.showingImageInspector = true
                            }, label: {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 100)
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                            })
                            .buttonStyle(.plain)
                            .help("Click to inspect")
                        } else {
                            Text(toolCall.result)
                                .font(.system(size: 10, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(5)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(3)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Helper Properties

    private var isThinkingMessage: Bool {
        self.message.role == .system && self.message.content.contains(AgentDisplayTokens.Status.planning)
    }

    private var isErrorMessage: Bool {
        self.message.role == .system && self.message.content.contains(AgentDisplayTokens.Status.failure)
    }

    private var isWarningMessage: Bool {
        self.message.role == .system && self.message.content.contains(AgentDisplayTokens.Status.warning)
    }

    private var isToolMessage: Bool {
        self.message
            .role == .system &&
            (self.message.content.contains(AgentDisplayTokens.Status.running) ||
                self.message.content.contains(AgentDisplayTokens.Status.success) ||
                self.message.content.contains(AgentDisplayTokens.Status.failure))
    }

    private var backgroundForMessage: Color {
        if self.isErrorMessage {
            Color.red.opacity(0.08)
        } else if self.isWarningMessage {
            Color.orange.opacity(0.08)
        } else if self.isThinkingMessage {
            Color.purple.opacity(0.05)
        } else if self.isToolMessage {
            Color.blue.opacity(0.05)
        } else {
            switch self.message.role {
            case .user:
                Color.blue.opacity(0.08)
            case .assistant:
                Color.green.opacity(0.08)
            case .system:
                Color.orange.opacity(0.08)
            }
        }
    }

    private var iconName: String {
        switch self.message.role {
        case .user: "person.circle"
        case .assistant: "brain"
        case .system: "gear"
        }
    }

    private var iconColor: Color {
        switch self.message.role {
        case .user: .blue
        case .assistant: .green
        case .system: .orange
        }
    }

    private var roleTitle: String {
        switch self.message.role {
        case .user: "You"
        case .assistant: "Agent"
        case .system: "System"
        }
    }

    // MARK: - Helper Methods

    private func extractToolName(from content: String) -> String {
        let cleaned = content
            .replacingOccurrences(of: AgentDisplayTokens.Status.running + " ", with: "")
            .replacingOccurrences(of: AgentDisplayTokens.Status.success + " ", with: "")
            .replacingOccurrences(of: AgentDisplayTokens.Status.failure + " ", with: "")

        if let colonIndex = cleaned.firstIndex(of: ":") {
            return String(cleaned[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    private func formatToolContent() -> String {
        self.message.content
            .replacingOccurrences(of: AgentDisplayTokens.Status.running + " ", with: "")
            .replacingOccurrences(of: AgentDisplayTokens.Status.success + " ", with: "")
            .replacingOccurrences(of: AgentDisplayTokens.Status.failure + " ", with: "")
    }

    private func determineToolStatus(from message: ConversationMessage) -> ToolExecutionStatus {
        if let toolCall = message.toolCalls.first {
            if toolCall.result == "Running..." {
                return .running
            }
            if !toolCall.result.isEmpty {
                if message.content.contains(AgentDisplayTokens.Status.failure) {
                    return .failed
                } else if message.content.contains(AgentDisplayTokens.Status.warning) {
                    return .cancelled
                } else {
                    return .completed
                }
            }
        }

        // Check agent's tool execution history
        let toolName = self.extractToolName(from: message.content)
        if !toolName.isEmpty {
            if let execution = agent.toolExecutionHistory.last(where: { $0.toolName == toolName }) {
                return execution.status
            }
        }

        // Fallback to content indicators
        if message.content.contains(AgentDisplayTokens.Status.success) {
            return .completed
        } else if message.content.contains(AgentDisplayTokens.Status.failure) {
            return .failed
        } else if message.content.contains(AgentDisplayTokens.Status.warning) {
            return .cancelled
        }

        return .running
    }

    private func formatCompactJSON(_ json: String) -> String {
        // For menu view, show compact single-line JSON
        guard let data = json.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data)
        else {
            return json
        }

        // Format as single line with minimal spacing
        if let formattedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]),
           let formattedString = String(data: formattedData, encoding: .utf8)
        {
            return formattedString
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
        }
        return json
    }

    private func extractImageData(from result: String) -> Data? {
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
        guard let session = sessionStore.sessions.first(where: { session in
            session.messages.contains(where: { $0.id == message.id })
        }) else { return }

        guard let errorIndex = session.messages.firstIndex(where: { $0.id == message.id }),
              errorIndex > 0 else { return }

        // Find last user message
        for i in stride(from: errorIndex - 1, through: 0, by: -1) {
            let msg = session.messages[i]
            if msg.role == .user {
                if self.sessionStore.currentSession?.id != session.id {
                    self.sessionStore.selectSession(session)
                }

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
