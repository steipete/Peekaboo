import AppKit
import PeekabooCore
import SwiftUI

// MARK: - Content Components

/// Main content area coordinator
struct StatusBarContentView: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore

    @Binding var detailsExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let session = self.sessionStore.currentSession {
                self.currentSessionSection(session: session)
            } else if !self.sessionStore.sessions.isEmpty {
                RecentSessionsView(detailsExpanded: self.$detailsExpanded)
            } else {
                EmptyStateView()
            }
        }
    }

    @ViewBuilder
    private func currentSessionSection(session: ConversationSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: self.$detailsExpanded) {
                UnifiedActivityFeed()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } label: {
                HStack(spacing: 8) {
                    Text(session.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if self.agent.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer(minLength: 0)

                    Text(self.detailsExpanded ? "Hide" : "Details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !self.detailsExpanded {
                SessionSummaryView(session: session)
            }
        }
    }
}

/// Empty state view for first-time users
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("No sessions yet")
                .font(.subheadline.weight(.semibold))

            Text("Ask Peekaboo something to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 18)
    }
}

/// Recent sessions display when no current session.
struct RecentSessionsView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Binding var detailsExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(self.detailsExpanded ? "Less" : "More") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        self.detailsExpanded.toggle()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(self.visibleSessions) { session in
                        Button {
                            self.sessionStore.selectSession(session)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "text.bubble")
                                    .foregroundStyle(.secondary)

                                Text(session.title)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Text(formatSessionDuration(session))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var visibleSessions: [ConversationSession] {
        let limit = self.detailsExpanded ? 8 : 3
        return Array(self.sessionStore.sessions.prefix(limit))
    }
}

private struct SessionSummaryView: View {
    let session: ConversationSession

    private var lastMessage: ConversationMessage? {
        self.session.messages.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lastMessage {
                Text(lastMessage.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                Text("Session is empty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6)))
    }
}
