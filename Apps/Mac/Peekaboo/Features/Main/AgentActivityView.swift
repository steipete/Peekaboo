import PeekabooCore
import SwiftUI

/// Displays all agent activity including messages and tool executions in chronological order
struct AgentActivityView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore

    /// Combined activity items from messages and tool executions
    private var activityItems: [AgentActivityItem] {
        var items: [AgentActivityItem] = []

        // Add messages from current session
        if let session = sessionStore.currentSession {
            for message in session.messages {
                // Skip user messages in the activity view
                if message.role == .user { continue }

                items.append(.message(message))
            }
        }

        // Add tool executions
        for execution in self.agent.toolExecutionHistory {
            items.append(.toolExecution(execution))
        }

        // Sort by timestamp
        return items.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        if !self.activityItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Label("Agent Activity", systemImage: "brain")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(self.activityItems.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Activity list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(self.activityItems) { item in
                        switch item {
                        case let .message(message):
                            AgentMessageRow(message: message)
                        case let .toolExecution(execution):
                            ToolExecutionRow(execution: execution)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }
}

/// Represents an activity item (either a message or tool execution)
enum AgentActivityItem: Identifiable {
    case message(ConversationMessage)
    case toolExecution(ToolExecution)

    var id: String {
        switch self {
        case let .message(msg):
            "msg-\(msg.id)"
        case let .toolExecution(exec):
            "tool-\(exec.toolName)-\(exec.timestamp.timeIntervalSince1970)"
        }
    }

    var timestamp: Date {
        switch self {
        case let .message(msg):
            msg.timestamp
        case let .toolExecution(exec):
            exec.timestamp
        }
    }
}

/// Row for displaying agent messages in the activity view
struct AgentMessageRow: View {
    let message: ConversationMessage
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Message type icon
                Image(systemName: self.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(self.iconColor)

                // Message preview
                Text(self.messagePreview)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .lineLimit(self.isExpanded ? nil : 2)

                Spacer()

                // Timestamp
                Text(self.message.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Expand button if message is long
                if self.message.content.count > 100 {
                    Button(action: { self.isExpanded.toggle() }) {
                        Image(systemName: self.isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Expanded full message
            if self.isExpanded {
                Text(self.message.content)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .padding(.leading, 22)
                    .padding(.top, 2)
            }
        }
    }

    private var iconName: String {
        switch self.message.role {
        case .assistant:
            "sparkles"
        case .system:
            "info.circle"
        case .user:
            "person.circle"
        }
    }

    private var iconColor: Color {
        switch self.message.role {
        case .assistant:
            .blue
        case .system:
            .orange
        case .user:
            .gray
        }
    }

    private var messagePreview: String {
        let trimmed = self.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "(Empty message)"
        }
        return trimmed
    }
}

#Preview {
    AgentActivityView()
        .frame(width: 400)
        .padding()
}
