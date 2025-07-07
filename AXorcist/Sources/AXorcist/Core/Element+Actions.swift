// Element+Actions.swift - Action-related methods for Element

import ApplicationServices
import Foundation

// Action-related extension for Element
extension Element {

    // MARK: - Actions

    @MainActor
    public func isActionSupported(_ actionName: String, isDebugLoggingEnabled: Bool,
                                  currentDebugLogs: inout [String]) -> Bool {
        // dLog is not directly used here, logging comes from the attribute call
        if let actions: [String] = attribute(
            Attribute<[String]>.actionNames,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs // This will respect the new dLog behavior in .attribute()
        ) {
            return actions.contains(actionName)
        }
        return false
    }

    @MainActor
    @discardableResult
    public func performAction(
        _ actionName: Attribute<String>,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) throws -> Element {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled && false {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }
        let error = AXUIElementPerformAction(self.underlyingElement, actionName.rawValue as CFString)
        if error != .success {
            // Now call the refactored briefDescription, passing the logs along.
            let desc = self.briefDescription(
                option: .default,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
            dLog("Action \(actionName.rawValue) failed on element \(desc). Error: \(error.rawValue)")
            throw AccessibilityError.actionFailed("Action \(actionName.rawValue) failed on element \(desc)", error)
        }
        return self
    }

    @MainActor
    @discardableResult
    public func performAction(_ actionName: String, isDebugLoggingEnabled: Bool,
                              currentDebugLogs: inout [String]) throws -> Element {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled && false {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }
        let error = AXUIElementPerformAction(self.underlyingElement, actionName as CFString)
        if error != .success {
            // Now call the refactored briefDescription, passing the logs along.
            let desc = self.briefDescription(
                option: .default,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
            dLog("Action \(actionName) failed on element \(desc). Error: \(error.rawValue)")
            throw AccessibilityError.actionFailed("Action \(actionName) failed on element \(desc)", error)
        }
        return self
    }
}
