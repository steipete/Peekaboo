import SwiftUI

struct SessionDetailView: View {
    let session: Session
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
    let message: SessionMessage

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
    let toolCall: ToolCall

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.fill")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(self.toolCall.name)
                .font(.caption)
                .foregroundColor(.secondary)

            if !self.toolCall.result.isEmpty {
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(self.toolCall.result)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
}
