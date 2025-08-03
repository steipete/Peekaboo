import PeekabooCore
import SwiftUI

struct SessionDetailView: View {
    let session: ConversationSession
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(self.session.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(self.session.startTime, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !self.session.summary.isEmpty {
                        Text(self.session.summary)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                Divider()

                // Messages
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(self.session.messages) { message in
                        SessionMessageRow(message: message)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
}

// Message row component (reused from MainWindow)
private struct SessionMessageRow: View {
    let message: ConversationMessage

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
                            SessionToolCallView(toolCall: toolCall)
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

// Tool call view (reused from MainWindow)
private struct SessionToolCallView: View {
    let toolCall: ConversationToolCall

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
