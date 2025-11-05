import PeekabooCore
import SwiftUI
import Tachikoma

struct EnhancedSessionDetailView: View {
    let session: ConversationSession
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PeekabooSettings.self) private var settings

    @State private var selectedTab: Tab = .session
    @State private var showAIAssistant = false

    enum Tab: String, CaseIterable {
        case session = "Session"
        case aiChat = "AI Assistant"
        case tools = "Tools"

        var systemImage: String {
            switch self {
            case .session:
                "bubble.left.and.bubble.right"
            case .aiChat:
                "brain.filled.head.profile"
            case .tools:
                "wrench.and.screwdriver"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button(action: {
                        self.selectedTab = tab
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                            Text(tab.rawValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            self.selectedTab == tab ?
                                Color.accentColor : Color.clear)
                        .foregroundColor(
                            self.selectedTab == tab ?
                                .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            Divider()

            // Tab content
            switch self.selectedTab {
            case .session:
                SessionDetailContent(session: self.session)

            case .aiChat:
                AIAssistantTab(sessionTitle: self.session.title)

            case .tools:
                ToolsTab(session: self.session)
            }
        }
        .navigationTitle(self.session.title)
    }
}

// MARK: - Session Detail Content

private struct SessionDetailContent: View {
    let session: ConversationSession

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
    }
}

// MARK: - AI Assistant Tab

private struct AIAssistantTab: View {
    let sessionTitle: String
    @State private var systemPrompt: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Context header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Assistant for Session")
                        .font(.headline)
                    Text(self.sessionTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Configure") {
                    // Show configuration sheet
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color.blue.opacity(0.1))

            // AI Chat interface
            CompactAIAssistant(
                systemPrompt: self.systemPrompt.isEmpty ?
                    "You are a helpful assistant analyzing the Peekaboo automation session '\(self.sessionTitle)'. Help the user understand the session data, troubleshoot issues, and improve their automation workflows." :
                    self.systemPrompt)
        }
        .onAppear {
            self.setupSystemPrompt()
        }
    }

    private func setupSystemPrompt() {
        self.systemPrompt = """
        You are an expert AI assistant for Peekaboo, a macOS automation tool. You're helping analyze the session titled "\(
            self
                .sessionTitle)".

        Your role:
        - Help users understand their automation sessions
        - Suggest improvements to automation workflows
        - Troubleshoot errors and issues
        - Explain Peekaboo commands and functionality
        - Provide code examples for Swift/SwiftUI integration

        Be specific, helpful, and focused on practical automation solutions.
        """
    }
}

// MARK: - Tools Tab

private struct ToolsTab: View {
    let session: ConversationSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                // Session tools used
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tools Used in Session")
                        .font(.headline)

                    ForEach(self.extractToolsUsed(), id: \.self) { tool in
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.blue)
                            Text(tool)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()

                Divider()

                // Available tools
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Peekaboo Tools")
                        .font(.headline)

                    ToolCategoryRow(
                        title: "Screen Capture",
                        tools: ["image", "see", "analyze"],
                        icon: "camera")

                    ToolCategoryRow(
                        title: "UI Interaction",
                        tools: ["click", "type", "scroll", "drag"],
                        icon: "hand.tap")

                    ToolCategoryRow(
                        title: "Window Management",
                        tools: ["window", "app", "space"],
                        icon: "macwindow")

                    ToolCategoryRow(
                        title: "System Control",
                        tools: ["hotkey", "menu", "dialog"],
                        icon: "gear")
                }
                .padding()
            }
        }
    }

    private func extractToolsUsed() -> [String] {
        // Extract tools from session messages
        // This would analyze the session data to find which tools were used
        ["click", "type", "image", "see"] // Placeholder
    }
}

private struct ToolCategoryRow: View {
    let title: String
    let tools: [String]
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: self.icon)
                    .foregroundColor(.accentColor)
                Text(self.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack {
                ForEach(self.tools, id: \.self) { tool in
                    Text(tool)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Message Row (reused from original)

private struct SessionMessageRow: View {
    let message: PeekabooCore.ConversationMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: self.iconName)
                .foregroundColor(self.iconColor)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(self.message.role.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(self.message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(self.message.content)
                    .font(.callout)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var iconName: String {
        switch self.message.role {
        case .user:
            "person.circle.fill"
        case .assistant:
            "brain.head.profile"
        case .system:
            "gear.circle.fill"
        }
    }

    private var iconColor: Color {
        switch self.message.role {
        case .user:
            .blue
        case .assistant:
            .green
        case .system:
            .orange
        }
    }
}

#Preview {
    EnhancedSessionDetailView(
        session: ConversationSession(
            id: "preview",
            title: "Screenshot and Analysis",
            messages: [
                PeekabooCore.ConversationMessage(role: .user, content: "Take a screenshot of Safari"),
                PeekabooCore.ConversationMessage(
                    role: .assistant,
                    content: "I'll take a screenshot of Safari for you."),
                PeekabooCore.ConversationMessage(role: .system, content: "Screenshot captured: safari_screenshot.png"),
            ],
            startTime: Date()))
        .frame(width: 800, height: 600)
}
