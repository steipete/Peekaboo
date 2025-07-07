import AppKit
import ApplicationServices
import Foundation

// Global constant for backwards compatibility - removed, now using AXMiscConstants.defaultMaxDepthSearch

// Placeholder for the actual accessibility logic.
// For now, this module is very thin and AXorcist.swift is the main public API.
// Other files like Element.swift, Models.swift, Search.swift, etc. are in Core/ Utils/ etc.

public class AXorcist {

    let focusedAppKeyValue = "focused"
    internal var recursiveCallDebugLogs: [String] = [] // Added for recursive logging

    // Default values for collection and search if not provided by the command
    public static let defaultMaxDepthCollectAll = 7 // Default recursion depth for collectAll
    public static let defaultMaxDepthSearch = 15 // Default recursion depth for search operations
    public static let defaultMaxDepthPathResolution = 15 // Max depth for resolving path hints
    public static let defaultMaxDepthDescribe = 5 // ADDED: Default for description recursion
    public static let defaultTimeoutPerElementCollectAll = 0.5 // seconds

    // Default attributes to fetch if none are specified by the command.
    public static let defaultAttributesToFetch: [String] = [
        "AXRole",
        "AXTitle",
        "AXSubrole",
        "AXIdentifier",
        "AXDescription",
        "AXValue",
        "AXSelectedText",
        "AXEnabled",
        "AXFocused"
    ]

    public init() {
        // Future initialization logic can go here.
        // For now, ensure debug logs can be collected if needed.
        // Note: The actual logging enable/disable should be managed per-call.
        // This init doesn't take global logging flags anymore.
    }

    @MainActor
    public static func formatDebugLogMessage(
        _ message: String,
        applicationName: String?,
        commandID: String?,
        file: String,
        function: String,
        line: Int
    ) -> String {
        let fileName = (file as NSString).lastPathComponent
        let appContext = applicationName != nil ? "[\(applicationName!)]" : ""
        let cmdContext = commandID != nil ? "[SubCmd: \(commandID!)]" : ""
        return "\(appContext)\(cmdContext)[\(fileName):\(line) \(function)] \(message)"
    }

    // Handler methods are implemented in extension files:
    // - handlePerformAction: AXorcist+ActionHandlers.swift
    // - handleExtractText: AXorcist+ActionHandlers.swift
    // - handleCollectAll: AXorcist+ActionHandlers.swift
    // - handleBatchCommands: AXorcist+BatchHandler.swift

    // handleExtractText method is implemented in AXorcist+ActionHandlers.swift

    // handleBatchCommands method is implemented in AXorcist+BatchHandler.swift

    // handleCollectAll method is implemented in AXorcist+ActionHandlers.swift

    // MARK: - Path Navigation

    // MARK: - Search Operations

    @MainActor
    public func search(
        element: Element,
        locator: Locator,
        requireAction: String?,
        depth: Int,
        maxDepth: Int,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> (foundElement: Element?, logs: [String]) {
        // Initial log for this AXorcist-level search call
        if isDebugLoggingEnabled {
            let initialMessage = "AXorcist.search called with locator: \(locator.criteria), path_hint: \(locator.root_element_path_hint ?? [])"
            currentDebugLogs.append(AXorcist.formatDebugLogMessage(initialMessage, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
        }

        // Call the global findElementViaPathAndCriteria
        // Note: findElementViaPathAndCriteria will handle its own detailed logging (dLog to currentDebugLogs if !JSON_LOG, or writeSearchLogEntry to stderr if JSON_LOG)
        let foundElement = findElementViaPathAndCriteria(
            application: element,
            locator: locator,
            maxDepth: maxDepth, // Assuming 'depth' passed to AXorcist.search is for initial call, maxDepth for traversal
            isDebugLoggingEnabledParam: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs // Pass this along for findElementViaPathAndCriteria to use
        )

        // The currentDebugLogs array has been populated by findElementViaPathAndCriteria (if JSON logging is off)
        // or contains only the initial logs from this function if JSON logging is on.
        return (foundElement: foundElement, logs: currentDebugLogs)
    }
}
