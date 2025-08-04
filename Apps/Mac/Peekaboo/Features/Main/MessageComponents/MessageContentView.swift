import SwiftUI
import PeekabooCore

// MARK: - Message Content View

struct MessageContentView: View {
    let message: ConversationMessage
    let isThinkingMessage: Bool
    let isErrorMessage: Bool
    let isWarningMessage: Bool
    let isToolMessage: Bool
    let extractToolName: (String) -> String
    
    var body: some View {
        if isThinkingMessage {
            // Show the actual thinking content, removing the 🤔 emoji
            Text(message.content.replacingOccurrences(of: "🤔 ", with: ""))
                .font(.system(.body))
                .foregroundColor(.purple)
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
            ToolMessageContent(message: message, extractToolName: extractToolName)
        } else if message.role == .assistant {
            AssistantMessageContent(message: message)
        } else {
            Text(message.content)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Tool Message Content

struct ToolMessageContent: View {
    let message: ConversationMessage
    let extractToolName: (String) -> String
    
    var body: some View {
        // Show tool execution details without inline icon (icon is in avatar position)
        if let toolCall = message.toolCalls.first {
            let isRunning = toolCall.result == "Running..."
            let content = message.content
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
                        let toolName = extractToolName(message.content)
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
                    TimeIntervalText(startTime: message.timestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .textSelection(.enabled)
        } else {
            Text(message.content
                .replacingOccurrences(of: "🔧 ", with: "")
                .replacingOccurrences(of: "✅ ", with: "")
                .replacingOccurrences(of: "❌ ", with: ""))
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Assistant Message Content

struct AssistantMessageContent: View {
    let message: ConversationMessage
    
    var body: some View {
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
            Text(message.content)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}