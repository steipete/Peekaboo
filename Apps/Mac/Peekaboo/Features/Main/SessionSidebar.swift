import SwiftUI
import PeekabooCore
import UniformTypeIdentifiers

// MARK: - Session Sidebar

struct SessionSidebar: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PeekabooAgent.self) private var agent

    @Binding var selectedSessionId: String?
    @Binding var searchText: String

    private var filteredSessions: [ConversationSession] {
        if self.searchText.isEmpty {
            self.sessionStore.sessions
        } else {
            self.sessionStore.sessions.filter { session in
                session.title.localizedCaseInsensitiveContains(self.searchText) ||
                    session.summary.localizedCaseInsensitiveContains(self.searchText) ||
                    session.messages.contains { message in
                        message.content.localizedCaseInsensitiveContains(self.searchText)
                    }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sessions")
                    .font(.headline)

                Spacer()

                Button(action: self.createNewSession) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New Session")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search sessions...", text: self.$searchText)
                    .textFieldStyle(.plain)
                if !self.searchText.isEmpty {
                    Button(action: { self.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Session list
            List(self.filteredSessions, selection: self.$selectedSessionId) { session in
                SessionRow(
                    session: session,
                    isActive: self.agent.currentSession?.id == session.id,
                    onDelete: { self.deleteSession(session) })
                    .tag(session.id)
                    .transition(.asymmetric(
                        insertion: .slide.combined(with: .opacity),
                        removal: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: self.filteredSessions.count)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            self.deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                    .contextMenu {
                        Button("Delete") {
                            self.deleteSession(session)
                        }
                        Button("Duplicate") {
                            self.duplicateSession(session)
                        }
                        Divider()
                        Button("Export...") {
                            self.exportSession(session)
                        }
                    }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top) {
                // Add padding at the top of the list content
                Color.clear
                    .frame(height: 8)
            }
            .onDeleteCommand {
                // Delete the currently selected session
                if let selectedId = selectedSessionId,
                   let session = sessionStore.sessions.first(where: { $0.id == selectedId }),
                   session.id != agent.currentSession?.id
                {
                    self.deleteSession(session)
                }
            }
        }
    }

    private func createNewSession() {
        let newSession = self.sessionStore.createSession(title: "New Session")
        self.selectedSessionId = newSession.id
    }

    private func deleteSession(_ session: ConversationSession) {
        // Don't delete active session
        guard session.id != self.agent.currentSession?.id else { return }

        self.sessionStore.sessions.removeAll { $0.id == session.id }
        Task {
            try? await self.sessionStore.saveSessions()
        }

        if self.selectedSessionId == session.id {
            self.selectedSessionId = nil
        }
    }

    private func duplicateSession(_ session: ConversationSession) {
        var newSession = ConversationSession(title: "\(session.title) (Copy)")
        newSession.messages = session.messages
        newSession.summary = session.summary

        self.sessionStore.sessions.insert(newSession, at: 0)
        Task {
            try? await self.sessionStore.saveSessions()
        }

        self.selectedSessionId = newSession.id
    }

    private func exportSession(_ session: ConversationSession) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(session.title).json"

        savePanel.begin { response in
            guard response == .OK else { return }

            // Capture URL on main thread before Task
            Task { @MainActor in
                guard let url = savePanel.url else { return }

                do {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(session)
                    try data.write(to: url)
                } catch {
                    print("Failed to export session: \(error)")
                }
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ConversationSession
    let isActive: Bool
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(self.session.title)
                    .font(.body)
                    .fontWeight(self.isActive ? .semibold : .regular)
                    .lineLimit(1)

                if self.isActive {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                        .symbolEffect(.pulse, options: .repeating)
                }

                Spacer()

                // Delete button on hover
                if self.isHovering, !self.isActive {
                    Button(action: self.onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete session")
                }
            }

            HStack {
                Text(self.session.startTime, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !self.session.messages.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("\(self.session.messages.count) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !self.session.modelName.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(formatModelName(self.session.modelName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !self.session.summary.isEmpty {
                Text(self.session.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
}