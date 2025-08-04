import SwiftUI
import PeekabooCore

// MARK: - Session Components

/// Compact session row for menu bar display
struct SessionRowCompact: View {
    let session: ConversationSession
    let isActive: Bool
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.session.title)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatSessionDuration(self.session))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if self.isHovering, !self.isActive {
                Button(action: self.onDelete) {
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
            self.isHovering = hovering
        }
    }
}

/// Current session preview with messages and stats
struct CurrentSessionPreview: View {
    let session: ConversationSession
    let tokenUsage: TokenUsage?
    let onOpenMainWindow: () -> Void

    var body: some View {
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
                Button(action: onOpenMainWindow) {
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

                if let tokenUsage = tokenUsage {
                    Label("\(tokenUsage.totalTokens)", systemImage: "circle.hexagongrid.circle")
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
        case .user: "person.circle"
        case .assistant: "brain"
        case .system: "gear"
        }
    }

    private func colorForRole(_ role: MessageRole) -> Color {
        switch role {
        case .user: .blue
        case .assistant: .green
        case .system: .orange
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

func formatSessionDuration(_ session: ConversationSession) -> String {
    let duration: TimeInterval = if let lastMessage = session.messages.last {
        lastMessage.timestamp.timeIntervalSince(session.startTime)
    } else {
        Date().timeIntervalSince(session.startTime)
    }

    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2

    return formatter.string(from: duration) ?? "0s"
}