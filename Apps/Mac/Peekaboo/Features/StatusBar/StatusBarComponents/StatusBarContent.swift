import PeekabooCore
import SwiftUI

// MARK: - Content Components

/// Main content area coordinator
struct StatusBarContentView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        Group {
            if self.sessionStore.currentSession != nil {
                // Show unified activity feed for current session
                UnifiedActivityFeed()
            } else if !self.sessionStore.sessions.isEmpty {
                // Show recent sessions when no active session
                RecentSessionsView()
            } else {
                // Empty state
                EmptyStateView()
            }
        }
    }
}

/// Empty state view for first-time users
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5))

            Text("Welcome to Peekaboo")
                .font(.title3)
                .fontWeight(.medium)

            Text("Ask me to help you with automation tasks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Recent sessions display when no current session
struct RecentSessionsView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(self.sessionStore.sessions.prefix(5)) { session in
                    SessionRowCompact(
                        session: session,
                        isActive: false, // No active session in this context
                        onDelete: {
                            withAnimation {
                                self.sessionStore.sessions.removeAll { $0.id == session.id }
                                Task { @MainActor in
                                    self.sessionStore.saveSessions()
                                }
                            }
                        })
                        .onTapGesture {
                            self.sessionStore.selectSession(session)
                            // Don't open main window - keep the popover experience
                        }
                }

                if self.sessionStore.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Text("No recent sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Start by asking me something")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
            .padding()
        }
    }
}
