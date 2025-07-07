// Element+Description.swift - Extension for Element description functionality

import ApplicationServices // For AXUIElement and other C APIs
import Foundation

// MARK: - Element Description Extension

extension Element {
    @MainActor
    public func briefDescription(option: ValueFormatOption = .default, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String {
        var descriptionParts: [String] = []
        var tempLogs: [String] = []

        if let role = self.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
            descriptionParts.append("Role: \(role)")
        }

        // PID, Title, ID, DOMId for .default and .verbose
        if option == .default || option == .verbose {
            var pidLogs: [String] = []
            if let pidValue = self.pid(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &pidLogs) {
                descriptionParts.append("PID: \(pidValue)")
            }
            if isDebugLoggingEnabled && false { currentDebugLogs.append(contentsOf: pidLogs) }

            if let title = self.title(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
                if !title.isEmpty {
                    descriptionParts.append("Title: '\(title.truncated(to: 50))'")
                }
            }

            if let id = self.identifier(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
                if !id.isEmpty {
                    descriptionParts.append("ID: '\(id.truncated(to: 50))'")
                }
            }

            if let domId = self.domIdentifier(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
                if !domId.isEmpty {
                    descriptionParts.append("DOMId: '\(domId.truncated(to: 50))'")
                }
            }
        }

        // Value and Help for .verbose only
        if option == .verbose {
            if let value = self.value(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
                let valueStr = String(describing: value)
                if !valueStr.isEmpty && valueStr != "nil" {
                    descriptionParts.append("Value: '\(valueStr.truncated(to: 80))'")
                }
            }

            if let help = self.help(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
                if !help.isEmpty {
                    descriptionParts.append("Help: '\(help.truncated(to: 80))'")
                }
            }
        }
        // For .short, only Role is included (implicitly from the first lines)

        if isDebugLoggingEnabled && false {
            currentDebugLogs.append(contentsOf: tempLogs)
        }

        if descriptionParts.isEmpty {
            if isDebugLoggingEnabled && false {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage("briefDescription: No descriptive attributes found, falling back to underlyingElement description.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
            return String(describing: self.underlyingElement)
        }

        // If .short and we have more than just Role (or Role+PID if PID was included for default), then shorten further.
        // This logic might need refinement based on desired .short output.
        if option == .short && descriptionParts.count > 1 {
            if let role = self.role(isDebugLoggingEnabled: false, currentDebugLogs: &tempLogs) { // Get role again without logging
                return "Role: \(role)" // Just return role for short
            } else {
                return descriptionParts.first ?? String(describing: self.underlyingElement) // Fallback for short
            }
        }

        return descriptionParts.joined(separator: ", ")
    }
}
