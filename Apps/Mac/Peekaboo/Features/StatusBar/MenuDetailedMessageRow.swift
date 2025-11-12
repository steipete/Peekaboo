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
            HStack(alignment: .top, spacing: self.compactSpacing) {
                self.avatarView
                    .frame(width: self.compactAvatarSize, height: self.compactAvatarSize)

                VStack(alignment: .leading, spacing: 4) {
                    MenuMessageHeaderView(
                        isToolMessage: self.isToolMessage,
                        toolName: self.extractToolName(from: self.message.content),
                        roleTitle: self.roleTitle,
                        isErrorMessage: self.isErrorMessage,
                        isWarningMessage: self.isWarningMessage,
                        timestamp: self.message.timestamp,
                        hasToolCalls: !self.message.toolCalls.isEmpty,
                        isExpanded: self.$isExpanded,
                        canRetry: self.isErrorMessage && !self.agent.isProcessing,
                        retryAction: self.retryLastTask)

                    MenuMessageContentView(
                        message: self.message,
                        isThinkingMessage: self.isThinkingMessage,
                        isToolMessage: self.isToolMessage,
                        formattedToolContent: self.formatToolContent(),
                        attributedAssistantContent: self.makeAssistantAttributedContent(),
                        isExpanded: self.isExpanded)

                    if self.isToolMessage, !self.message.toolCalls.isEmpty {
                        ToolExecutionSummaryView(
                            message: self.message)
                    }
                }

                Spacer(minLength: 0)
            }

            if self.isExpanded, !self.message.toolCalls.isEmpty {
                MenuToolDetailsView(
                    toolCalls: self.message.toolCalls,
                    formatCompactJSON: self.formatCompactJSON,
                    extractImageData: self.extractImageData,
                    selectImage: { image in
                        self.selectedImage = image
                        self.showingImageInspector = true
                    })
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

    private func makeAssistantAttributedContent() -> AttributedString? {
        try? AttributedString(
            markdown: self.message.content,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace))
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

// MARK: - Subviews

private struct MenuMessageHeaderView: View {
    let isToolMessage: Bool
    let toolName: String
    let roleTitle: String
    let isErrorMessage: Bool
    let isWarningMessage: Bool
    let timestamp: Date
    let hasToolCalls: Bool
    @Binding var isExpanded: Bool
    let canRetry: Bool
    let retryAction: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if self.isToolMessage {
                Text(self.toolName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            } else {
                Text(self.roleTitle)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            if self.isErrorMessage {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            } else if self.isWarningMessage {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(self.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            if self.hasToolCalls {
                Button {
                    self.isExpanded.toggle()
                } label: {
                    Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(self.isExpanded ? "Hide details" : "Show details")
            }

            if self.canRetry {
                Button(action: self.retryAction) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Color.red)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("Retry task")
            }
        }
    }
}

private struct MenuMessageContentView: View {
    let message: ConversationMessage
    let isThinkingMessage: Bool
    let isToolMessage: Bool
    let formattedToolContent: String
    let attributedAssistantContent: AttributedString?
    let isExpanded: Bool

    var body: some View {
        if self.isThinkingMessage {
            ThinkingContentView(text: self.message.content)
        } else if self.isToolMessage {
            ToolMessageView(
                toolCalls: self.message.toolCalls,
                formattedToolContent: self.formattedToolContent,
                timestamp: self.message.timestamp)
        } else if self.message.role == .assistant {
            AssistantContentView(
                message: self.message,
                attributedAssistantContent: self.attributedAssistantContent,
                isExpanded: self.isExpanded)
        } else {
            Text(self.message.content)
                .font(.caption)
                .foregroundColor(self.statusColor)
                .lineLimit(self.isExpanded ? nil : 2)
                .textSelection(.enabled)
        }
    }

    private var statusColor: Color {
        if self.message.content.contains(AgentDisplayTokens.Status.failure) {
            return .red
        }
        if self.message.content.contains(AgentDisplayTokens.Status.warning) {
            return .orange
        }
        return .primary
    }
}

private struct ToolExecutionSummaryView: View {
    let message: ConversationMessage

    var body: some View {
        if let toolCall = self.message.toolCalls.first,
           toolCall.result != "Running...",
           let resultSummary = ToolFormatter.toolResultSummary(toolName: toolCall.name, result: toolCall.result)
        {
            Text(resultSummary)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

private struct MenuToolDetailsView: View {
    let toolCalls: [ConversationToolCall]
    let formatCompactJSON: (String) -> String
    let extractImageData: (String) -> Data?
    let selectImage: (NSImage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(self.toolCalls) { toolCall in
                VStack(alignment: .leading, spacing: 4) {
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

                    if !toolCall.result.isEmpty, toolCall.result != "Running..." {
                        Text("Result:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if self.shouldShowImage(for: toolCall),
                           let data = self.extractImageData(toolCall.result),
                           let image = NSImage(data: data)
                        {
                            Button {
                                self.selectImage(image)
                            } label: {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 100)
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                            }
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

    private func shouldShowImage(for toolCall: ConversationToolCall) -> Bool {
        toolCall.name.contains("image") || toolCall.name.contains("screenshot")
    }
}

// MARK: - Nested Content Views

private struct ThinkingContentView: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Text(
                self.text.replacingOccurrences(
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
    }
}

private struct ToolMessageView: View {
    let toolCalls: [ConversationToolCall]
    let formattedToolContent: String
    let timestamp: Date

    var body: some View {
        if let toolCall = self.toolCalls.first,
           toolCall.result == "Running..."
        {
            HStack(spacing: 4) {
                Text(self.formattedToolContent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                TimeIntervalText(startTime: self.timestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        } else {
            Text(self.formattedToolContent)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

private struct AssistantContentView: View {
    let message: ConversationMessage
    let attributedAssistantContent: AttributedString?
    let isExpanded: Bool

    var body: some View {
        if let attributedAssistantContent {
            Text(attributedAssistantContent)
                .font(.caption)
                .lineLimit(self.isExpanded ? nil : 3)
                .textSelection(.enabled)
        } else {
            Text(self.message.content)
                .font(.caption)
                .lineLimit(self.isExpanded ? nil : 3)
                .textSelection(.enabled)
        }
    }
}
