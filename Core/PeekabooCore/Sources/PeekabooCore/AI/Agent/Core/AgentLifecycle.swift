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
        let timestamp = self.includeTimestamps ? "[\(self.formatTimestamp())] " : ""

        switch event {
        case let .agentStarted(agent, context):
            print("\(timestamp)🚀 Agent '\(agent)' started")
            if let context, verbose {
                print("   Context: \(context)")
            }

        case let .agentEnded(agent, output):
            print("\(timestamp)✅ Agent '\(agent)' completed")
            if let output, verbose {
                print("   Output: \(output.prefix(100))...")
            }

        case let .toolStarted(name, arguments):
            if self.verbose {
                print("\(timestamp)🔧 Tool '\(name)' started")
                print("   Args: \(arguments)")
            }

        case let .toolEnded(name, result, success):
            if self.verbose {
                let icon = success ? "✓" : "✗"
                print("\(timestamp)🔧 Tool '\(name)' \(icon)")
                if !success {
                    print("   Result: \(result)")
                }
            }

        case let .handoffStarted(from, to, reason):
            print("\(timestamp)🤝 Handoff: '\(from)' → '\(to)'")
            if let reason {
                print("   Reason: \(reason)")
            }

        case let .handoffCompleted(from, to):
            print("\(timestamp)🤝 Handoff completed: '\(from)' → '\(to)'")

        case let .iterationStarted(number):
            if self.verbose {
                print("\(timestamp)🔄 Iteration \(number) started")
            }

        case let .iterationCompleted(number):
            if self.verbose {
                print("\(timestamp)🔄 Iteration \(number) completed")
            }

        case let .errorOccurred(error, context):
            print("\(timestamp)❌ Error: \(error.localizedDescription)")
            if let context {
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
        case let .agentStarted(agent, _):
            self.metrics.totalExecutions += 1
            self.executionStarts[agent] = Date()

        case let .agentEnded(agent, _):
            if let startTime = executionStarts[agent] {
                let duration = Date().timeIntervalSince(startTime)
                if self.metrics.executionTimes[agent] == nil {
                    self.metrics.executionTimes[agent] = []
                }
                self.metrics.executionTimes[agent]?.append(duration)
                self.executionStarts.removeValue(forKey: agent)
                self.metrics.successfulExecutions += 1
            }

        case let .toolStarted(name, _):
            self.metrics.totalToolCalls += 1
            self.toolStarts[name] = Date()

        case let .toolEnded(name, _, success):
            if let startTime = toolStarts[name] {
                let duration = Date().timeIntervalSince(startTime)
                if self.metrics.toolExecutionTimes[name] == nil {
                    self.metrics.toolExecutionTimes[name] = []
                }
                self.metrics.toolExecutionTimes[name]?.append(duration)
                self.toolStarts.removeValue(forKey: name)

                if success {
                    self.metrics.successfulToolCalls += 1
                } else {
                    self.metrics.failedToolCalls += 1
                }
            }

        case .handoffStarted:
            self.metrics.totalHandoffs += 1

        case .iterationStarted:
            self.metrics.totalIterations += 1

        case .errorOccurred:
            self.metrics.totalErrors += 1

        default:
            break
        }
    }

    public func getMetrics() -> Metrics {
        self.metrics
    }

    public func reset() {
        self.metrics = Metrics()
        self.executionStarts.removeAll()
        self.toolStarts.removeAll()
    }
}

/// Manager for lifecycle handlers
public actor LifecycleManager {
    private var handlers: [any AgentLifecycleHandler] = []

    public init(handlers: [any AgentLifecycleHandler] = []) {
        self.handlers = handlers
    }

    public func addHandler(_ handler: any AgentLifecycleHandler) {
        self.handlers.append(handler)
    }

    public func removeAllHandlers() {
        self.handlers.removeAll()
    }

    public func emit(_ event: AgentLifecycleEvent) async {
        // Emit to all handlers concurrently
        await withTaskGroup(of: Void.self) { group in
            for handler in self.handlers {
                group.addTask {
                    await handler.handle(event: event)
                }
            }
        }
    }
}
