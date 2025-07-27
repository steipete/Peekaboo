import Foundation

/// Events that can occur during agent execution
public enum AgentLifecycleEvent: Sendable {
    case agentStarted(agent: String, context: String?)
    case agentEnded(agent: String, output: String?)
    case toolStarted(name: String, arguments: String)
    case toolEnded(name: String, result: String, success: Bool)
    case handoffStarted(from: String, to: String, reason: String?)
    case handoffCompleted(from: String, to: String)
    case iterationStarted(number: Int)
    case iterationCompleted(number: Int)
    case errorOccurred(error: Error, context: String?)
}

/// Protocol for lifecycle event handlers
public protocol AgentLifecycleHandler: Actor {
    func handle(event: AgentLifecycleEvent) async
}

/// Default console logger for lifecycle events
public actor ConsoleLifecycleHandler: AgentLifecycleHandler {
    private let verbose: Bool
    private let includeTimestamps: Bool
    
    public init(verbose: Bool = false, includeTimestamps: Bool = true) {
        self.verbose = verbose
        self.includeTimestamps = includeTimestamps
    }
    
    public func handle(event: AgentLifecycleEvent) async {
        let timestamp = includeTimestamps ? "[\(formatTimestamp())] " : ""
        
        switch event {
        case .agentStarted(let agent, let context):
            print("\(timestamp)🚀 Agent '\(agent)' started")
            if let context = context, verbose {
                print("   Context: \(context)")
            }
            
        case .agentEnded(let agent, let output):
            print("\(timestamp)✅ Agent '\(agent)' completed")
            if let output = output, verbose {
                print("   Output: \(output.prefix(100))...")
            }
            
        case .toolStarted(let name, let arguments):
            if verbose {
                print("\(timestamp)🔧 Tool '\(name)' started")
                print("   Args: \(arguments)")
            }
            
        case .toolEnded(let name, let result, let success):
            if verbose {
                let icon = success ? "✓" : "✗"
                print("\(timestamp)🔧 Tool '\(name)' \(icon)")
                if !success {
                    print("   Result: \(result)")
                }
            }
            
        case .handoffStarted(let from, let to, let reason):
            print("\(timestamp)🤝 Handoff: '\(from)' → '\(to)'")
            if let reason = reason {
                print("   Reason: \(reason)")
            }
            
        case .handoffCompleted(let from, let to):
            print("\(timestamp)🤝 Handoff completed: '\(from)' → '\(to)'")
            
        case .iterationStarted(let number):
            if verbose {
                print("\(timestamp)🔄 Iteration \(number) started")
            }
            
        case .iterationCompleted(let number):
            if verbose {
                print("\(timestamp)🔄 Iteration \(number) completed")
            }
            
        case .errorOccurred(let error, let context):
            print("\(timestamp)❌ Error: \(error.localizedDescription)")
            if let context = context {
                print("   Context: \(context)")
            }
        }
    }
    
    private func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}

/// Metrics collector for agent execution
public actor MetricsLifecycleHandler: AgentLifecycleHandler {
    public struct Metrics {
        public var totalExecutions = 0
        public var successfulExecutions = 0
        public var failedExecutions = 0
        public var totalToolCalls = 0
        public var successfulToolCalls = 0
        public var failedToolCalls = 0
        public var totalIterations = 0
        public var totalHandoffs = 0
        public var totalErrors = 0
        public var executionTimes: [String: [TimeInterval]] = [:]
        public var toolExecutionTimes: [String: [TimeInterval]] = [:]
    }
    
    private var metrics = Metrics()
    private var executionStarts: [String: Date] = [:]
    private var toolStarts: [String: Date] = [:]
    
    public init() {}
    
    public func handle(event: AgentLifecycleEvent) async {
        switch event {
        case .agentStarted(let agent, _):
            metrics.totalExecutions += 1
            executionStarts[agent] = Date()
            
        case .agentEnded(let agent, _):
            if let startTime = executionStarts[agent] {
                let duration = Date().timeIntervalSince(startTime)
                if metrics.executionTimes[agent] == nil {
                    metrics.executionTimes[agent] = []
                }
                metrics.executionTimes[agent]?.append(duration)
                executionStarts.removeValue(forKey: agent)
                metrics.successfulExecutions += 1
            }
            
        case .toolStarted(let name, _):
            metrics.totalToolCalls += 1
            toolStarts[name] = Date()
            
        case .toolEnded(let name, _, let success):
            if let startTime = toolStarts[name] {
                let duration = Date().timeIntervalSince(startTime)
                if metrics.toolExecutionTimes[name] == nil {
                    metrics.toolExecutionTimes[name] = []
                }
                metrics.toolExecutionTimes[name]?.append(duration)
                toolStarts.removeValue(forKey: name)
                
                if success {
                    metrics.successfulToolCalls += 1
                } else {
                    metrics.failedToolCalls += 1
                }
            }
            
        case .handoffStarted:
            metrics.totalHandoffs += 1
            
        case .iterationStarted:
            metrics.totalIterations += 1
            
        case .errorOccurred:
            metrics.totalErrors += 1
            
        default:
            break
        }
    }
    
    public func getMetrics() -> Metrics {
        return metrics
    }
    
    public func reset() {
        metrics = Metrics()
        executionStarts.removeAll()
        toolStarts.removeAll()
    }
}

/// Manager for lifecycle handlers
public actor LifecycleManager {
    private var handlers: [any AgentLifecycleHandler] = []
    
    public init(handlers: [any AgentLifecycleHandler] = []) {
        self.handlers = handlers
    }
    
    public func addHandler(_ handler: any AgentLifecycleHandler) {
        handlers.append(handler)
    }
    
    public func removeAllHandlers() {
        handlers.removeAll()
    }
    
    public func emit(_ event: AgentLifecycleEvent) async {
        // Emit to all handlers concurrently
        await withTaskGroup(of: Void.self) { group in
            for handler in handlers {
                group.addTask {
                    await handler.handle(event: event)
                }
            }
        }
    }
}