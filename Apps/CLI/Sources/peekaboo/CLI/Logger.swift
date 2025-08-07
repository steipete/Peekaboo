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
    
    public func operationStart(_ operation: String, metadata: [String: Any]? = nil) {
        getLogger(for: "Operations").info("Starting operation: \(operation)", metadata: metadata)
    }
    
    public func operationComplete(_ operation: String, metadata: [String: Any]? = nil) {
        getLogger(for: "Operations").info("Completed operation: \(operation)", metadata: metadata)
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
        let mappedCategory: String
        switch category {
        case "Capture", "ScreenCapture":
            mappedCategory = LoggingService.Category.screenCapture
        case "Automation":
            mappedCategory = LoggingService.Category.automation
        case "AI":
            mappedCategory = LoggingService.Category.ai
        case "Permissions":
            mappedCategory = LoggingService.Category.permissions
        case "LabelPlacement":
            mappedCategory = LoggingService.Category.labelPlacement
        case "Performance":
            mappedCategory = LoggingService.Category.performance
        case "Error":
            mappedCategory = LoggingService.Category.error
        default:
            mappedCategory = category
        }
        
        let logger = loggingService.logger(category: mappedCategory)
        categoryLoggers[category] = logger
        return logger
    }
}