import SwiftUI
import PeekabooCore

/// Enhanced message row for menu bar with full agent flow visualization
struct MenuDetailedMessageRow: View {
    let message: ConversationMessage
    @State private var isExpanded = false
    @State private var showingImageInspector = false
    @State private var selectedImage: NSImage?
    @Environment(PeekabooAgent.self) private var agent
    @Environment(SessionStore.self) private var sessionStore
    
    private let compactAvatarSize: CGFloat = 20
    private let compactSpacing: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: compactSpacing) {
            // Main message content
            HStack(alignment: .top, spacing: compactSpacing) {
                // Compact avatar or tool icon
                avatarView
                    .frame(width: compactAvatarSize, height: compactAvatarSize)
                
                // Message content
                VStack(alignment: .leading, spacing: 4) {
                    // Header line with role, time, and status
                    headerView
                    
                    // Message content
                    contentView
                    
                    // Tool execution summary (if applicable)
                    if isToolMessage && !message.toolCalls.isEmpty {
                        toolExecutionSummary
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // Expandable tool details
            if isExpanded && !message.toolCalls.isEmpty {
                toolDetailsView
                    .padding(.leading, compactAvatarSize + compactSpacing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(backgroundForMessage)
        .cornerRadius(6)
        .sheet(isPresented: $showingImageInspector) {
            if let image = selectedImage {
                ImageInspectorView(image: image)
            }
        }
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private var avatarView: some View {
        if isToolMessage {
            let toolName = extractToolName(from: message.content)
            let toolStatus = determineToolStatus(from: message)
            
            EnhancedToolIcon(
                toolName: toolName,
                status: toolStatus
            )
            .font(.system(size: 14))
            .background(Color.blue.opacity(0.1))
            .clipShape(Circle())
        } else if isThinkingMessage {
            ZStack {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
                
                // Subtle rotation animation
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(360))
                    .animation(
                        Animation.linear(duration: 3)
                            .repeatForever(autoreverses: false),
                        value: true
                    )
            }
        } else {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(iconColor)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
        }
    }
    
    // MARK: - Header View
    
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 4) {
            // Role or tool name
            if isToolMessage {
                Text(extractToolName(from: message.content))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            } else {
                Text(roleTitle)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Status indicators
            if isErrorMessage {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            } else if isWarningMessage {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            // Time
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Expand button for tool calls
            if !message.toolCalls.isEmpty {
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Hide details" : "Show details")
            }
            
            // Retry button for errors
            if isErrorMessage && !agent.isProcessing {
                Button(action: retryLastTask) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Color.red)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("Retry task")
            }
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if isThinkingMessage {
            HStack(spacing: 4) {
                Text(message.content.replacingOccurrences(of: "🤔 ", with: ""))
                    .font(.caption)
                    .foregroundColor(.purple)
                    .italic()
                    .lineLimit(2)
                
                if #available(macOS 15.0, *) {
                    AnimatedThinkingDots()
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
        } else if isToolMessage {
            // Compact tool display
            if let toolCall = message.toolCalls.first {
                let isRunning = toolCall.result == "Running..."
                
                HStack(spacing: 4) {
                    Text(formatToolContent())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if isRunning {
                        TimeIntervalText(startTime: message.timestamp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(formatToolContent())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        } else if message.role == .assistant {
            // Markdown support for assistant messages
            Text(try! AttributedString(
                markdown: message.content,
                options: AttributedString.MarkdownParsingOptions(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            ))
            .font(.caption)
            .lineLimit(isExpanded ? nil : 3)
            .textSelection(.enabled)
        } else {
            Text(message.content)
                .font(.caption)
                .foregroundColor(isErrorMessage ? .red : (isWarningMessage ? .orange : .primary))
                .lineLimit(isExpanded ? nil : 2)
                .textSelection(.enabled)
        }
    }
    
    // MARK: - Tool Execution Summary
    
    @ViewBuilder
    private var toolExecutionSummary: some View {
        if let toolCall = message.toolCalls.first,
           toolCall.result != "Running...",
           let toolName = message.toolCalls.first?.name,
           let resultSummary = ToolFormatter.toolResultSummary(toolName: toolName, result: toolCall.result) {
            Text(resultSummary)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    // MARK: - Tool Details View
    
    @ViewBuilder
    private var toolDetailsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(message.toolCalls) { toolCall in
                VStack(alignment: .leading, spacing: 4) {
                    // Arguments (if not empty)
                    if !toolCall.arguments.isEmpty && toolCall.arguments != "{}" {
                        Text("Arguments:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(formatCompactJSON(toolCall.arguments))
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(3)
                    }
                    
                    // Result (if available)
                    if !toolCall.result.isEmpty && toolCall.result != "Running..." {
                        Text("Result:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        // Check for image data
                        if toolCall.name.contains("image") || toolCall.name.contains("screenshot"),
                           let imageData = extractImageData(from: toolCall.result),
                           let image = NSImage(data: imageData) {
                            
                            Button(action: {
                                selectedImage = image
                                showingImageInspector = true
                            }) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 100)
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Click to inspect")
                        } else {
                            Text(toolCall.result)
                                .font(.system(size: 10, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(5)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(3)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var isThinkingMessage: Bool {
        message.role == .system && message.content.contains("🤔")
    }
    
    private var isErrorMessage: Bool {
        message.role == .system && message.content.contains("❌")
    }
    
    private var isWarningMessage: Bool {
        message.role == .system && message.content.contains("⚠️")
    }
    
    private var isToolMessage: Bool {
        message.role == .system && (message.content.contains("🔧") || message.content.contains("✅") || message.content.contains("❌"))
    }
    
    private var backgroundForMessage: Color {
        if isErrorMessage {
            return Color.red.opacity(0.08)
        } else if isWarningMessage {
            return Color.orange.opacity(0.08)
        } else if isThinkingMessage {
            return Color.purple.opacity(0.05)
        } else if isToolMessage {
            return Color.blue.opacity(0.05)
        } else {
            switch message.role {
            case .user:
                return Color.blue.opacity(0.08)
            case .assistant:
                return Color.green.opacity(0.08)
            case .system:
                return Color.orange.opacity(0.08)
            }
        }
    }
    
    private var iconName: String {
        switch message.role {
        case .user: return "person.circle"
        case .assistant: return "brain"
        case .system: return "gear"
        }
    }
    
    private var iconColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .orange
        }
    }
    
    private var roleTitle: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Agent"
        case .system: return "System"
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractToolName(from content: String) -> String {
        let cleaned = content
            .replacingOccurrences(of: "🔧 ", with: "")
            .replacingOccurrences(of: "✅ ", with: "")
            .replacingOccurrences(of: "❌ ", with: "")
        
        if let colonIndex = cleaned.firstIndex(of: ":") {
            return String(cleaned[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
    
    private func formatToolContent() -> String {
        message.content
            .replacingOccurrences(of: "🔧 ", with: "")
            .replacingOccurrences(of: "✅ ", with: "")
            .replacingOccurrences(of: "❌ ", with: "")
    }
    
    private func determineToolStatus(from message: ConversationMessage) -> ToolExecutionStatus {
        if let toolCall = message.toolCalls.first {
            if toolCall.result == "Running..." {
                return .running
            }
            if !toolCall.result.isEmpty {
                if message.content.contains("❌") {
                    return .failed
                } else if message.content.contains("⚠️") {
                    return .cancelled
                } else {
                    return .completed
                }
            }
        }
        
        // Check agent's tool execution history
        let toolName = extractToolName(from: message.content)
        if !toolName.isEmpty {
            if let execution = agent.toolExecutionHistory.last(where: { $0.toolName == toolName }) {
                return execution.status
            }
        }
        
        // Fallback to content indicators
        if message.content.contains("✅") {
            return .completed
        } else if message.content.contains("❌") {
            return .failed
        } else if message.content.contains("⚠️") {
            return .cancelled
        }
        
        return .running
    }
    
    private func formatCompactJSON(_ json: String) -> String {
        // For menu view, show compact single-line JSON
        guard let data = json.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return json
        }
        
        // Format as single line with minimal spacing
        if let formattedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]),
           let formattedString = String(data: formattedData, encoding: .utf8) {
            return formattedString
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
        }
        return json
    }
    
    private func extractImageData(from result: String) -> Data? {
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let screenshotData = json["screenshot_data"] as? String,
           let imageData = Data(base64Encoded: screenshotData) {
            return imageData
        }
        return nil
    }
    
    private func retryLastTask() {
        guard let session = sessionStore.sessions.first(where: { session in
            session.messages.contains(where: { $0.id == message.id })
        }) else { return }
        
        guard let errorIndex = session.messages.firstIndex(where: { $0.id == message.id }),
              errorIndex > 0 else { return }
        
        // Find last user message
        for i in stride(from: errorIndex - 1, through: 0, by: -1) {
            let msg = session.messages[i]
            if msg.role == .user {
                if sessionStore.currentSession?.id != session.id {
                    sessionStore.selectSession(session)
                }
                
                Task {
                    do {
                        try await agent.executeTask(msg.content)
                    } catch {
                        print("Retry failed: \(error)")
                    }
                }
                break
            }
        }
    }
}