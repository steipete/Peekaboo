import Combine
import PeekabooCore
import SwiftUI

// MARK: - Activity Items

/// Represents a unified activity item in the feed
enum ActivityItem: Identifiable {
    case thinking(id: UUID = UUID(), content: String, timestamp: Date)
    case toolExecution(ToolExecution)
    case message(ConversationMessage)

    var id: String {
        switch self {
        case let .thinking(id, _, _):
            "thinking-\(id)"
        case let .toolExecution(execution):
            "tool-\(execution.toolName)-\(execution.timestamp.timeIntervalSince1970)"
        case let .message(message):
            "msg-\(message.id)"
        }
    }

    var timestamp: Date {
        switch self {
        case let .thinking(_, _, timestamp):
            timestamp
        case let .toolExecution(execution):
            execution.timestamp
        case let .message(message):
            message.timestamp
        }
    }
}

// MARK: - Main Feed View

/// Unified activity feed showing all agent activities chronologically
struct UnifiedActivityFeed: View {
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var userIsScrolling = false
    @State private var lastActivityCount = 0

    private var activities: [ActivityItem] {
        var items: [ActivityItem] = []

        // Add messages from current session
        if let session = sessionStore.currentSession {
            for message in session.messages {
                // Extract thinking messages
                if message.role == .system, message.content.contains(AgentDisplayTokens.Status.planning) {
                    items.append(.thinking(
                        content: message.content.replacingOccurrences(
                            of: "\(AgentDisplayTokens.Status.planning) ",
                            with: ""),
                        timestamp: message.timestamp))
                } else {
                    items.append(.message(message))
                }
            }
        }

        // Add tool executions
        for execution in self.agent.toolExecutionHistory {
            items.append(.toolExecution(execution))
        }

        // Add current thinking state
        if self.agent.isThinking, let thinkingContent = agent.currentThinkingContent {
            items.append(.thinking(
                content: thinkingContent,
                timestamp: Date()))
        }

        // Sort by timestamp
        return items.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(self.activities) { activity in
                        ActivityItemView(activity: activity)
                            .id(activity.id)
                            .transition(.asymmetric(
                                insertion: .push(from: .top).combined(with: .opacity),
                                removal: .push(from: .bottom).combined(with: .opacity)))
                    }

                    // Bottom padding for better scrolling
                    Color.clear
                        .frame(height: 20)
                        .id("bottom")
                }
                .animation(.easeInOut(duration: 0.3), value: self.activities.count)
            }
            .onAppear {
                self.scrollViewProxy = proxy
                self.lastActivityCount = self.activities.count
            }
            .onChange(of: self.activities.count) { oldCount, newCount in
                // Auto-scroll to new content if user isn't manually scrolling
                if newCount > oldCount, !self.userIsScrolling {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                self.lastActivityCount = newCount
            }
            // Track scroll position changes to detect user scrolling
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { _ in
                // User has scrolled, disable auto-scroll temporarily
                self.userIsScrolling = true

                // Re-enable auto-scroll after a delay
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    self.userIsScrolling = false
                }
            }
        }
    }
}

// MARK: - Activity Item View

/// View for individual activity items
struct ActivityItemView: View {
    let activity: ActivityItem
    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        Group {
            switch self.activity {
            case let .thinking(_, content, _):
                ThinkingActivityView(content: content)
            case let .toolExecution(execution):
                ToolActivityView(execution: execution, isExpanded: self.$isExpanded)
            case let .message(message):
                MessageActivityView(message: message, isExpanded: self.$isExpanded)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
    }
}

// MARK: - Thinking Activity View

struct ThinkingActivityView: View {
    let content: String
    @State private var animationPhase = 0.0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Animated brain icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: "brain")
                    .font(.system(size: 16))
                    .foregroundColor(.purple)
                    .symbolEffect(.pulse, options: .repeating.speed(0.8))

                // Subtle rotation ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .purple.opacity(0.1), .clear],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 2)
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(self.animationPhase))
                    .onAppear {
                        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                            self.animationPhase = 360
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Thinking")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple)

                    if #available(macOS 15.0, *) {
                        AnimatedThinkingDots()
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                    }
                }

                Text(self.content)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.05))
    }
}

// MARK: - Tool Activity View

struct ToolActivityView: View {
    let execution: ToolExecution
    @Binding var isExpanded: Bool
    @State private var showingResult = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            HStack(alignment: .top, spacing: 10) {
                // Tool icon with status
                ZStack {
                    Circle()
                        .fill(self.backgroundColorForStatus)
                        .frame(width: 28, height: 28)

                    EnhancedToolIcon(
                        toolName: self.execution.toolName,
                        status: self.execution.status)
                        .font(.system(size: 16))
                        .foregroundColor(self.iconColorForStatus)
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Tool name and status
                    HStack(spacing: 6) {
                        Text(self.execution.toolName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)

                        if self.execution.status == .running {
                            TimeIntervalText(startTime: self.execution.timestamp)
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        } else if let duration = execution.duration {
                            Text(ToolFormatter.formatDuration(duration))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }

                    // Compact summary
                    Text(self.toolSummary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(self.isExpanded ? nil : 1)

                    // Result preview (if completed)
                    if self.execution.status == .completed,
                       let resultSummary = ToolFormatter.toolResultSummary(
                           toolName: execution.toolName,
                           result: execution.result)
                    {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundColor(.green)

                            Text(resultSummary)
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                                .lineLimit(self.isExpanded ? nil : 1)
                        }
                    } else if self.execution.status == .failed {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.red)

                            Text(self.execution.result ?? "Failed")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                                .lineLimit(self.isExpanded ? nil : 1)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Expand button
                if self.hasExpandableContent {
                    Button(action: { withAnimation { self.isExpanded.toggle() } }, label: {
                        Image(systemName: self.isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    })
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Expanded details
            if self.isExpanded {
                ToolDetailsView(execution: self.execution)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(self.backgroundColorForView)
    }

    private var toolSummary: String {
        ToolFormatter.compactToolSummary(
            toolName: self.execution.toolName,
            arguments: self.execution.arguments ?? "")
    }

    private var hasExpandableContent: Bool {
        !(self.execution.arguments?.isEmpty ?? true) || self.execution.result != nil
    }

    private var backgroundColorForStatus: Color {
        switch self.execution.status {
        case .running: .orange.opacity(0.1)
        case .completed: .green.opacity(0.1)
        case .failed: .red.opacity(0.1)
        case .cancelled: .gray.opacity(0.1)
        }
    }

    private var iconColorForStatus: Color {
        switch self.execution.status {
        case .running: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: .gray
        }
    }

    private var backgroundColorForView: Color {
        switch self.execution.status {
        case .running: .orange.opacity(0.03)
        case .completed: .green.opacity(0.03)
        case .failed: .red.opacity(0.05)
        case .cancelled: .gray.opacity(0.03)
        }
    }
}

// MARK: - Tool Details View

struct ToolDetailsView: View {
    let execution: ToolExecution

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Arguments
            if let arguments = execution.arguments, !arguments.isEmpty, arguments != "{}" {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Arguments", systemImage: "arrow.right.square")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(self.formattedJSON(arguments))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(6)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                }
            }

            // Result
            if let result = execution.result, !result.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Result", systemImage: "checkmark.square")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(self.formattedJSON(result))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(6)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                        .lineLimit(10)
                }
            }

            // Error
            if self.execution.status == .failed, let error = execution.result {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Error", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)

                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.leading, 38) // Align with content
    }

    private func formattedJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyString = String(data: prettyData, encoding: .utf8)
        else {
            return json
        }
        return prettyString
    }
}

// MARK: - Message Activity View

struct MessageActivityView: View {
    let message: ConversationMessage
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(self.avatarBackgroundColor)
                        .frame(width: 28, height: 28)

                    Image(systemName: self.avatarIcon)
                        .font(.system(size: 14))
                        .foregroundColor(self.avatarColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Role and timestamp
                    HStack(spacing: 6) {
                        Text(self.roleTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)

                        Text(self.message.timestamp, style: .time)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    // Message content
                    if self.message.role == .assistant {
                        Text(self.assistantMarkdown)
                            .font(.system(size: 11))
                            .lineLimit(self.isExpanded ? nil : 3)
                    } else {
                        Text(self.cleanedContent)
                            .font(.system(size: 11))
                            .foregroundColor(self.contentColor)
                            .lineLimit(self.isExpanded ? nil : 2)
                    }
                }

                Spacer(minLength: 0)

                // Expand button for long messages
                if self.message.content.count > 150 {
                    Button(action: { withAnimation { self.isExpanded.toggle() } }, label: {
                        Image(systemName: self.isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    })
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Tool calls (if any)
            if !self.message.toolCalls.isEmpty, self.isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(self.message.toolCalls) { toolCall in
                        ToolCallView(toolCall: toolCall)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(self.messageBackgroundColor)
    }

    private var avatarIcon: String {
        switch self.message.role {
        case .user: "person.fill"
        case .assistant: "sparkles"
        case .system: "gear"
        }
    }

    private var avatarColor: Color {
        switch self.message.role {
        case .user: .blue
        case .assistant: .green
        case .system: .orange
        }
    }

    private var avatarBackgroundColor: Color {
        switch self.message.role {
        case .user: .blue.opacity(0.1)
        case .assistant: .green.opacity(0.1)
        case .system: .orange.opacity(0.1)
        }
    }

    private var roleTitle: String {
        switch self.message.role {
        case .user: "You"
        case .assistant: "Assistant"
        case .system: "System"
        }
    }

    private var cleanedContent: String {
        self.message.content
            .replacingOccurrences(of: AgentDisplayTokens.Status.running + " ", with: "")
            .replacingOccurrences(of: AgentDisplayTokens.Status.success + " ", with: "")
            .replacingOccurrences(of: AgentDisplayTokens.Status.failure + " ", with: "")
            .replacingOccurrences(of: "\(AgentDisplayTokens.Status.warning) ", with: "")
    }

    private var contentColor: Color {
        if self.message.content.contains(AgentDisplayTokens.Status.failure) { return .red }
        if self.message.content.contains(AgentDisplayTokens.Status.warning) { return .orange }
        return .primary
    }

    private var messageBackgroundColor: Color {
        if self.message.content.contains(AgentDisplayTokens.Status.failure) { return .red.opacity(0.05) }
        if self.message.content.contains(AgentDisplayTokens.Status.warning) { return .orange.opacity(0.05) }

        switch self.message.role {
        case .user: return .blue.opacity(0.03)
        case .assistant: return .green.opacity(0.03)
        case .system: return .orange.opacity(0.03)
        }
    }

    private var assistantMarkdown: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: self.message.content, options: options)) ??
            AttributedString(self.message.content)
    }

}

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ConversationToolCall

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "function")
                .font(.system(size: 10))
                .foregroundColor(.blue)

            Text(self.toolCall.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.blue)

            if let args = parseArguments(toolCall.arguments) {
                Text(args)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
        .padding(.leading, 38)
    }

    private func parseArguments(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let params = dict.compactMap { key, value in
            "\(key): \(value)"
        }.joined(separator: ", ")

        return params.isEmpty ? nil : "(\(params))"
    }
}

// MARK: - Animated Thinking Dots

@available(macOS 15.0, *)
struct AnimatedThinkingDots: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Text(".")
                    .opacity(self.animationPhase == index ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.4).delay(Double(index) * 0.2), value: self.animationPhase)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                Task { @MainActor in
                    self.animationPhase = (self.animationPhase + 1) % 3
                }
            }
        }
    }

    private var assistantMarkdown: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: self.message.content, options: options)) ??
            AttributedString(self.message.content)
    }
}

// MARK: - Scroll Position Tracking

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
