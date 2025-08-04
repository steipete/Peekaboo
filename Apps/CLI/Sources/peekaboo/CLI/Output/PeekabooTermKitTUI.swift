import Foundation
import TermKit
import PeekabooCore

/// TermKit-based TUI implementation for Peekaboo Agent
@available(macOS 14.0, *)
@MainActor
final class PeekabooTermKitTUI {
    private var app: Application?
    private var window: Window?
    
    // UI Components
    private var statusLabel: Label?
    private var progressBar: ProgressBar?
    private var toolsListView: ListView?
    private var outputTextView: TextView?
    
    // State
    private var currentTask = ""
    private var currentStep = 0
    private var maxSteps = 20
    private var modelName = ""
    private var startTime = Date()
    private var toolHistory: [ToolExecution] = []
    private var outputLines: [String] = []
    private var isRunning = false
    
    struct ToolExecution {
        let name: String
        let startTime: Date
        var endTime: Date?
        var status: Status = .running
        let summary: String
        
        enum Status {
            case running, completed, failed
            
            var symbol: String {
                switch self {
                case .running: return "→"
                case .completed: return "✓"
                case .failed: return "✗"
                }
            }
            
            // TODO: Add color support once we understand TermKit's color system better
        }
    }
    
    func start(agentTask: @escaping () async throws -> Void) {
        guard !isRunning else { return }
        
        // Initialize TermKit
        Application.prepare()
        
        // Create main window
        window = Window()
        window?.title = "Peekaboo Agent"
        
        setupUI()
        
        // Run the agent task in background
        Task { @MainActor in
            do {
                try await agentTask()
            } catch {
                self.addError("Agent error: \(error.localizedDescription)")
                // Auto-exit after error
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.stop()
                }
            }
        }
        
        // Run the TUI (blocks until Application.requestStop is called)
        isRunning = true
        Application.run()
    }
    
    func stop() {
        guard isRunning else { return }
        Application.requestStop()
        isRunning = false
    }
    
    private func setupUI() {
        guard window != nil else { return }
        
        let top = Toplevel()
        
        // Header Frame
        let headerFrame = Frame("Agent Status")
        headerFrame.x = Pos.at(0)
        headerFrame.y = Pos.at(0)
        headerFrame.width = Dim.fill()
        headerFrame.height = Dim.sized(5)
        
        // Status label
        statusLabel = Label("Task: \(currentTask)")
        statusLabel?.x = Pos.at(1)
        statusLabel?.y = Pos.at(1)
        headerFrame.addSubview(statusLabel!)
        
        // Progress bar
        progressBar = ProgressBar()
        progressBar?.x = Pos.at(1)
        progressBar?.y = Pos.at(2)
        progressBar?.width = Dim.fill() - 2  // Leave 1 char margin on each side
        progressBar?.fraction = 0.0
        headerFrame.addSubview(progressBar!)
        
        // Model and stats label
        let modelLabel = Label("Model: \(modelName)")
        modelLabel.x = Pos.at(1)
        modelLabel.y = Pos.at(3)
        headerFrame.addSubview(modelLabel)
        
        top.addSubview(headerFrame)
        
        // Tools Frame (left side)
        let toolsFrame = Frame("Tools & History")
        toolsFrame.x = Pos.at(0)
        toolsFrame.y = Pos.bottom(of: headerFrame)
        toolsFrame.width = Dim.percent(n: 30)
        toolsFrame.height = Dim.fill() - 1  // Leave margin at bottom
        
        // Tools history text (using TextView instead of ListView for simplicity)
        let toolsTextView = TextView()
        toolsTextView.x = Pos.at(1)
        toolsTextView.y = Pos.at(1)
        toolsTextView.width = Dim.fill() - 2
        toolsTextView.height = Dim.fill() - 2
        toolsTextView.canFocus = false
        toolsTextView.text = "Tools will appear here..."
        toolsFrame.addSubview(toolsTextView)
        
        // Store reference to update later
        self.toolsListView = nil  // Not using ListView for now
        
        top.addSubview(toolsFrame)
        
        // Output Frame (right side)
        let outputFrame = Frame("Output")
        outputFrame.x = Pos.right(of: toolsFrame)
        outputFrame.y = Pos.bottom(of: headerFrame)
        outputFrame.width = Dim.fill()
        outputFrame.height = Dim.fill() - 1
        
        // Output text view
        outputTextView = TextView()
        outputTextView?.x = Pos.at(1)
        outputTextView?.y = Pos.at(1)
        outputTextView?.width = Dim.fill() - 2
        outputTextView?.height = Dim.fill() - 2
        outputTextView?.canFocus = false
        outputFrame.addSubview(outputTextView!)
        
        top.addSubview(outputFrame)
        
        // Bottom status bar
        let statusBar = Label("Press Ctrl+C to exit")
        statusBar.x = Pos.at(0)
        statusBar.y = Pos.anchorEnd(margin: 1)
        statusBar.width = Dim.fill()
        statusBar.textAlignment = .centered
        statusBar.colorScheme = Colors.menu
        top.addSubview(statusBar)
        
        Application.top.addSubview(top)
    }
    
    // MARK: - Public Interface
    
    func startTask(_ task: String, maxSteps: Int, modelName: String) {
        self.currentTask = task
        self.maxSteps = maxSteps
        self.modelName = modelName
        self.currentStep = 0
        self.startTime = Date()
        
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel?.text = "Task: \(task.prefix(50))..."
            self?.updateProgress()
            self?.addOutput("🚀 Starting: \(task)", style: .system)
            self?.addOutput("🤖 Model: \(modelName)", style: .system)
        }
    }
    
    func startTool(_ name: String, summary: String) {
        currentStep += 1
        
        let execution = ToolExecution(
            name: name,
            startTime: Date(),
            summary: summary
        )
        toolHistory.append(execution)
        
        DispatchQueue.main.async { [weak self] in
            self?.updateProgress()
            self?.updateToolsList()
            self?.addOutput("\(iconForTool(name)) \(name): \(summary)", style: .tool)
        }
    }
    
    func completeTool(_ name: String, success: Bool, resultSummary: String) {
        // Update tool history
        if let index = toolHistory.firstIndex(where: { $0.name == name && $0.endTime == nil }) {
            toolHistory[index].endTime = Date()
            toolHistory[index].status = success ? .completed : .failed
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateToolsList()
            
            let status = success ? "✓" : "✗"
            let style: OutputStyle = success ? .success : .error
            self?.addOutput("\(status) \(resultSummary)", style: style)
        }
    }
    
    func addAssistantMessage(_ content: String) {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.addOutput(content, style: .assistant)
            }
        }
    }
    
    func addThinkingMessage(_ content: String) {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.addOutput("💭 \(content)", style: .thinking)
            }
        }
    }
    
    func addError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.addOutput("❌ Error: \(message)", style: .error)
        }
    }
    
    func completeTask() {
        let duration = Date().timeIntervalSince(startTime)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.progressBar?.fraction = 1.0
            self.addOutput("✅ Task completed in \(self.formatDuration(duration))", style: .system)
            
            // Keep TUI open for 2 seconds to show completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.stop()
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func updateProgress() {
        let progress = Float(currentStep) / Float(maxSteps)
        progressBar?.fraction = progress
        
        let elapsed = Date().timeIntervalSince(startTime)
        let stats = "Step \(currentStep)/\(maxSteps) • \(formatDuration(elapsed))"
        
        // Update progress info
        if let window = window {
            window.title = "Peekaboo Agent - \(stats)"
        }
    }
    
    private func updateToolsList() {
        var items: [String] = []
        
        // Current running tool
        if let currentTool = toolHistory.last(where: { $0.endTime == nil }) {
            items.append("🎯 Current: \(currentTool.name)")
            items.append("")
        }
        
        // Recent completed tools
        items.append("📋 History:")
        
        // Show last 10 tools
        let recentTools = toolHistory.suffix(10)
        for tool in recentTools {
            let duration = tool.endTime.map { formatDuration($0.timeIntervalSince(tool.startTime)) } ?? "..."
            let line = "\(tool.status.symbol) \(tool.name) (\(duration))"
            items.append(line)
        }
        
        // TODO: Update ListView items when TermKit API is better understood
        // For now, tools history will be shown in the output text
    }
    
    private enum OutputStyle {
        case system, tool, assistant, thinking, success, error
        
        var prefix: String {
            switch self {
            case .system: return "[SYS] "
            case .tool: return "[TOOL] "
            case .assistant: return ""
            case .thinking: return "[THINK] "
            case .success: return "[OK] "
            case .error: return "[ERR] "
            }
        }
    }
    
    private func addOutput(_ text: String, style: OutputStyle) {
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )
        
        let line = "[\(timestamp)] \(style.prefix)\(text)"
        outputLines.append(line)
        
        // Keep last 1000 lines
        if outputLines.count > 1000 {
            outputLines.removeFirst(outputLines.count - 1000)
        }
        
        // Update text view
        outputTextView?.text = outputLines.joined(separator: "\n")
        
        // Scroll to bottom to show latest output
        outputTextView?.scrollToBottom()
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1.0 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            return String(format: "%dm %ds", minutes, remainingSeconds)
        }
    }
    
}

// MARK: - TermKit Agent Event Delegate

@available(macOS 14.0, *)
@MainActor
final class TermKitAgentEventDelegate: PeekabooCore.AgentEventDelegate {
    private let tui: PeekabooTermKitTUI
    
    init(tui: PeekabooTermKitTUI) {
        self.tui = tui
    }
    
    func agentDidEmitEvent(_ event: PeekabooCore.AgentEvent) {
        switch event {
        case .started:
            // Task start is handled when TUI initializes
            break
            
        case let .toolCallStarted(name, arguments):
            let summary = parseToolSummary(name: name, arguments: arguments)
            tui.startTool(name, summary: summary)
            
        case let .toolCallCompleted(name, result):
            let (success, summary) = parseToolResult(name: name, result: result)
            tui.completeTool(name, success: success, resultSummary: summary)
            
        case let .assistantMessage(content):
            tui.addAssistantMessage(content)
            
        case let .thinkingMessage(content):
            tui.addThinkingMessage(content)
            
        case let .error(message):
            tui.addError(message)
            
        case .completed:
            tui.completeTask()
        }
    }
    
    private func parseToolSummary(name: String, arguments: String) -> String {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        
        switch name {
        case "see":
            if let app = args["app"] as? String {
                return app
            } else if let mode = args["mode"] as? String {
                return mode == "window" ? "active window" : mode
            }
            return "screen"
            
        case "click":
            if let target = args["target"] as? String {
                return "'\(target)'"
            } else if let element = args["element"] as? String {
                return "element \(element)"
            }
            return ""
            
        case "type":
            if let text = args["text"] as? String {
                return "'\(text.prefix(30))'"
            }
            return ""
            
        case "list_apps":
            return "running applications"
            
        case "list_windows":
            if let app = args["app"] as? String {
                return "windows for \(app)"
            }
            return "all windows"
            
        default:
            return ""
        }
    }
    
    private func parseToolResult(name: String, result: String) -> (success: Bool, summary: String) {
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (true, "Completed")
        }
        
        let success = json["success"] as? Bool ?? true
        
        // Extract meaningful summary from result
        switch name {
        case "see":
            if success {
                return (true, "Captured screen")
            }
            
        case "click":
            if success, let elementData = json["element"] as? [String: Any],
               let title = elementData["title"] as? String {
                return (true, "Clicked '\(title)'")
            }
            
        case "type":
            if success {
                return (true, "Text entered")
            }
            
        case "list_apps":
            if let apps = json["apps"] as? [[String: Any]] {
                return (true, "\(apps.count) apps found")
            }
            
        case "list_windows":
            if let windows = json["windows"] as? [[String: Any]] {
                return (true, "\(windows.count) windows found")
            }
            
        default:
            break
        }
        
        return (success, success ? "Completed" : "Failed")
    }
}