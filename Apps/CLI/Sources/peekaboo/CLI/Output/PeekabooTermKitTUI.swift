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
        
        // IMPORTANT: Cannot call Application.run() from MainActor context
        // because it calls dispatch_main() which crashes when already on main queue.
        // Need to run the TUI setup and agent task without blocking dispatch_main.
        
        // Initialize TermKit with Unix driver to avoid macOS curses issues
        // See: https://github.com/migueldeicaza/TermKit commit 5fee151
        // Force Unix driver for now since curses still has issues on macOS 15.x
        Application.prepare(driverType: .unix)
        
        // Create main window
        window = Window()
        window?.title = "Peekaboo Agent"
        
        setupUI()
        
        // Start the agent task asynchronously
        Task {
            do {
                try await agentTask()
                // Auto-complete after successful execution
                await MainActor.run {
                    self.addOutput("✅ Task completed successfully", style: .system)
                }
                
                // Keep TUI visible for 2 seconds then exit
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    self.stop()
                }
            } catch {
                await MainActor.run {
                    self.addError("Agent error: \(error.localizedDescription)")
                }
                
                // Keep error visible for 3 seconds then exit
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.stop()
                }
            }
        }
        
        // Set running state but don't call Application.run() 
        // to avoid dispatch_main() crash
        isRunning = true
        
        // Instead of Application.run(), we'll simulate basic TUI behavior
        // This is a temporary workaround until TermKit can be used safely
        // from MainActor contexts
        simulateBasicTUI()
    }
    
    func stop() {
        guard isRunning else { return }
        
        // Only call requestStop if we actually started the Application run loop
        // Since we're avoiding Application.run() to prevent dispatch_main() crash,
        // we don't need to call requestStop()
        // Application.requestStop()
        
        isRunning = false
        print("═══════════════════════════════════════════════════════════")
        print("🏁 Agent session ended")
    }
    
    private func setupUI() {
        guard window != nil else { return }
        
        let top = Toplevel()
        
        // Simplified single frame for now to avoid layout crashes
        let mainFrame = Frame("Peekaboo Agent")
        mainFrame.x = Pos.at(0)
        mainFrame.y = Pos.at(0)
        mainFrame.width = Dim.fill()
        mainFrame.height = Dim.fill()
        
        // Status label
        statusLabel = Label("Task: \(currentTask)")
        statusLabel?.x = Pos.at(2)
        statusLabel?.y = Pos.at(2)
        mainFrame.addSubview(statusLabel!)
        
        // Progress bar - simplified
        progressBar = ProgressBar()
        progressBar?.x = Pos.at(2)
        progressBar?.y = Pos.at(4)
        progressBar?.width = Dim.sized(50)  // Fixed width to avoid arithmetic issues
        progressBar?.fraction = 0.0
        mainFrame.addSubview(progressBar!)
        
        // Model label
        let modelLabel = Label("Model: \(modelName)")
        modelLabel.x = Pos.at(2)
        modelLabel.y = Pos.at(6)
        mainFrame.addSubview(modelLabel)
        
        // Output text view - simplified
        outputTextView = TextView()
        outputTextView?.x = Pos.at(2)
        outputTextView?.y = Pos.at(8)
        outputTextView?.width = Dim.sized(80)  // Fixed width
        outputTextView?.height = Dim.sized(15) // Fixed height
        outputTextView?.canFocus = false
        outputTextView?.text = "Peekaboo Agent started...\n"
        mainFrame.addSubview(outputTextView!)
        
        top.addSubview(mainFrame)
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
    
    /// Temporary workaround for TermKit's dispatch_main() issue
    /// This provides basic output without the full TUI functionality
    private func simulateBasicTUI() {
        // For now, just provide console output instead of full TUI
        // The real UI events will still be sent via the event delegate
        print("🖥️  Peekaboo Agent TUI Mode")
        print("📝 Task: \(currentTask)")
        print("🤖 Model: \(modelName)")
        print("⏱️  Started at \(DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .medium))")
        print("═══════════════════════════════════════════════════════════")
        
        // The agent task is already running in the background Task
        // UI updates will come through the event delegate system
        // This is a simpler fallback until TermKit can be fixed
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