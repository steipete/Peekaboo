import Foundation
import os

/// Default implementation of LoggingServiceProtocol using Apple's unified logging
public final class LoggingService: LoggingServiceProtocol, @unchecked Sendable {
    private let subsystem: String
    private var loggers: [String: os.Logger]
    private let queue = DispatchQueue(label: "boo.peekaboo.logging", attributes: .concurrent)
    private var performanceMeasurements = [String: (startTime: Date, operation: String, correlationId: String?)]()

    public var minimumLogLevel: LogLevel = .info {
        didSet {
            self.queue.async(flags: .barrier) {
                self.updateLogLevel()
            }
        }
    }

    /// Initialize with subsystem identifier
    public init(subsystem: String = "boo.peekaboo.core") {
        self.subsystem = subsystem
        self.loggers = [:]

        // Set initial log level from environment
        if let envLevel = ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() {
            switch envLevel {
            case "trace": self.minimumLogLevel = .trace
            case "debug": self.minimumLogLevel = .debug
            case "info": self.minimumLogLevel = .info
            case "warning", "warn": self.minimumLogLevel = .warning
            case "error": self.minimumLogLevel = .error
            case "critical": self.minimumLogLevel = .critical
            default: break
            }
        }
    }

    /// Get or create a Logger for the specified category
    private func osLogger(category: String) -> os.Logger {
        self.queue.sync {
            if let logger = loggers[category] {
                return logger
            }
            let logger = os.Logger(subsystem: subsystem, category: category)
            return logger
        }
    }

    /// Store a logger for reuse
    private func storeLogger(_ logger: os.Logger, category: String) {
        self.queue.async(flags: .barrier) {
            self.loggers[category] = logger
        }
    }

    public func log(_ entry: LogEntry) {
        guard entry.level >= self.minimumLogLevel else { return }

        let logger = self.osLogger(category: entry.category)
        self.storeLogger(logger, category: entry.category)

        // Convert metadata to structured format
        var logMessage = entry.message
        if !entry.metadata.isEmpty {
            let metadataString = entry.metadata
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            logMessage += " | \(metadataString)"
        }

        if let correlationId = entry.correlationId {
            logMessage = "[\(correlationId)] \(logMessage)"
        }

        // Log at appropriate level
        switch entry.level {
        case .trace:
            logger.trace("\(logMessage)")
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .critical:
            logger.critical("\(logMessage)")
        }
    }

    public func startPerformanceMeasurement(operation: String, correlationId: String?) -> String {
        let measurementId = UUID().uuidString
        self.queue.async(flags: .barrier) {
            self.performanceMeasurements[measurementId] = (Date(), operation, correlationId)
        }
        return measurementId
    }

    public func endPerformanceMeasurement(measurementId: String, metadata: [String: Any] = [:]) {
        self.queue.sync {
            guard let measurement = performanceMeasurements[measurementId] else {
                return
            }

            let duration = Date().timeIntervalSince(measurement.startTime)
            var performanceMetadata = metadata
            performanceMetadata["duration_ms"] = Int(duration * 1000)
            performanceMetadata["operation"] = measurement.operation

            let level: LogLevel = duration > 1.0 ? .warning : .debug
            self.log(LogEntry(
                level: level,
                message: "Performance: \(measurement.operation) completed",
                category: "Performance",
                metadata: performanceMetadata,
                correlationId: measurement.correlationId))
        }

        self.queue.async(flags: .barrier) {
            self.performanceMeasurements.removeValue(forKey: measurementId)
        }
    }

    public func logger(category: String) -> CategoryLogger {
        CategoryLogger(service: self, category: category)
    }

    private func updateLogLevel() {
        // This is where we could update os.log settings if Apple provided an API for it
        // For now, we just use our internal minimumLogLevel for filtering
    }
}

/// Standard log categories for Peekaboo
extension LoggingService {
    public enum Category {
        static let screenCapture = "ScreenCapture"
        static let automation = "Automation"
        static let windows = "Windows"
        static let applications = "Applications"
        static let menu = "Menu"
        static let dock = "Dock"
        static let dialogs = "Dialogs"
        static let sessions = "Sessions"
        static let files = "Files"
        static let configuration = "Configuration"
        static let process = "Process"
        static let ai = "AI"
        static let performance = "Performance"
        static let permissions = "Permissions"
        static let error = "Error"
        static let labelPlacement = "LabelPlacement"
    }
}

/// Mock implementation for testing
public final class MockLoggingService: LoggingServiceProtocol, @unchecked Sendable {
    public var minimumLogLevel: LogLevel = .trace
    public var loggedEntries: [LogEntry] = []
    public var performanceMeasurements: [String: (startTime: Date, operation: String)] = [:]

    public func log(_ entry: LogEntry) {
        guard entry.level >= self.minimumLogLevel else { return }
        self.loggedEntries.append(entry)
    }

    public func startPerformanceMeasurement(operation: String, correlationId: String?) -> String {
        let id = UUID().uuidString
        self.performanceMeasurements[id] = (Date(), operation)
        return id
    }

    public func endPerformanceMeasurement(measurementId: String, metadata: [String: Any]) {
        if let measurement = performanceMeasurements.removeValue(forKey: measurementId) {
            let duration = Date().timeIntervalSince(measurement.startTime)
            var perfMetadata = metadata
            perfMetadata["duration_ms"] = Int(duration * 1000)

            self.log(LogEntry(
                level: .debug,
                message: "Performance: \(measurement.operation) completed",
                category: "Performance",
                metadata: perfMetadata))
        }
    }

    public func logger(category: String) -> CategoryLogger {
        CategoryLogger(service: self, category: category)
    }
}
