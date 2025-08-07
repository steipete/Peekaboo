//
//  Logger.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

/// Global logger instance for CLI commands
/// This bridges to PeekabooCore's LoggingService infrastructure
public final class Logger {
    public static let shared = Logger()
    
    private var loggingService: LoggingServiceProtocol
    private var categoryLoggers: [String: CategoryLogger] = [:]
    private var isVerbose: Bool = false
    
    private init() {
        self.loggingService = PeekabooServices.shared.logging
    }
    
    // MARK: - Configuration
    
    public func setVerboseMode(_ verbose: Bool) {
        self.isVerbose = verbose
        if verbose {
            loggingService.setMinimumLogLevel(.debug)
        } else {
            loggingService.setMinimumLogLevel(.info)
        }
    }
    
    // MARK: - Logging Methods
    
    public func verbose(_ message: String, category: String = "CLI", metadata: [String: Any]? = nil) {
        guard isVerbose else { return }
        getLogger(for: category).debug(message, metadata: metadata)
    }
    
    public func debug(_ message: String, category: String = "CLI", metadata: [String: Any]? = nil) {
        getLogger(for: category).debug(message, metadata: metadata)
    }
    
    public func info(_ message: String, category: String = "CLI", metadata: [String: Any]? = nil) {
        getLogger(for: category).info(message, metadata: metadata)
    }
    
    public func warning(_ message: String, category: String = "CLI", metadata: [String: Any]? = nil) {
        getLogger(for: category).warning(message, metadata: metadata)
    }
    
    public func error(_ message: String, category: String = "CLI", metadata: [String: Any]? = nil) {
        getLogger(for: category).error(message, metadata: metadata)
    }
    
    // MARK: - Operation Tracking
    
    private var timers: [String: Date] = [:]
    
    public func startTimer(_ label: String) {
        timers[label] = Date()
    }
    
    public func stopTimer(_ label: String) {
        guard let startTime = timers[label] else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        timers.removeValue(forKey: label)
        verbose("Timer '\(label)' completed in \(String(format: "%.2f", elapsed))s", category: "Performance")
    }
    
    public func operationStart(_ operation: String, metadata: [String: Any]? = nil) {
        getLogger(for: "Operations").info("Starting operation: \(operation)", metadata: metadata)
    }
    
    public func operationComplete(_ operation: String, metadata: [String: Any]? = nil) {
        getLogger(for: "Operations").info("Completed operation: \(operation)", metadata: metadata)
    }
    
    public func operationComplete(_ operation: String, success: Bool, metadata: [String: Any]? = nil) {
        var fullMetadata = metadata ?? [:]
        fullMetadata["success"] = success
        let level = success ? "info" : "warning"
        if success {
            getLogger(for: "Operations").info("Completed operation: \(operation)", metadata: fullMetadata)
        } else {
            getLogger(for: "Operations").warning("Completed operation with issues: \(operation)", metadata: fullMetadata)
        }
    }
    
    public func operationFailed(_ operation: String, error: Error, metadata: [String: Any]? = nil) {
        var fullMetadata = metadata ?? [:]
        fullMetadata["error"] = String(describing: error)
        getLogger(for: "Operations").error("Failed operation: \(operation)", metadata: fullMetadata)
    }
    
    // MARK: - Private Helpers
    
    private func getLogger(for category: String) -> CategoryLogger {
        if let logger = categoryLoggers[category] {
            return logger
        }
        
        // Map common categories to PeekabooCore categories
        // Using string literals since LoggingService.Category members are internal
        let mappedCategory: String
        switch category {
        case "Capture", "ScreenCapture":
            mappedCategory = "ScreenCapture"
        case "Automation":
            mappedCategory = "Automation"
        case "AI":
            mappedCategory = "AI"
        case "Permissions":
            mappedCategory = "Permissions"
        case "LabelPlacement":
            mappedCategory = "LabelPlacement"
        case "Performance":
            mappedCategory = "Performance"
        case "Error":
            mappedCategory = "Error"
        default:
            mappedCategory = category
        }
        
        let logger = loggingService.logger(category: mappedCategory)
        categoryLoggers[category] = logger
        return logger
    }
}