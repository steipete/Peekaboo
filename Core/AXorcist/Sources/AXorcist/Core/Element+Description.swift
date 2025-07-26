// Element+Description.swift - Extension for Element description functionality

import ApplicationServices // For AXUIElement and other C APIs
import Foundation

// GlobalAXLogger should be available from AXorcistLib/Logging/GlobalAXLogger.swift

// MARK: - Element Description Extension

extension Element {
    @MainActor
    public func briefDescription(option: ValueFormatOption = .smart) -> String {
        var descriptionParts: [String] = []

        // Always add role if available
        addRoleDescription(to: &descriptionParts)

        // Add standard details for smart and stringified
        if option == .smart || option == .stringified {
            addStandardDetails(to: &descriptionParts)
        }

        // Add verbose details for stringified option
        if option == .stringified {
            addVerboseDetails(to: &descriptionParts)
        }

        // Handle empty description
        if descriptionParts.isEmpty {
            return handleEmptyDescription()
        }

        // Handle raw option
        if option == .raw, descriptionParts.count > 1 {
            return formatShortDescription(descriptionParts)
        }

        return descriptionParts.joined(separator: ", ")
    }

    @MainActor
    private func addRoleDescription(to parts: inout [String]) {
        if let role = self.role() {
            parts.append("Role: \(role)")
        }
    }

    @MainActor
    private func addStandardDetails(to parts: inout [String]) {
        if let pidValue = self.pid() {
            parts.append("PID: \(pidValue)")
        }

        addNonEmptyAttribute(self.title(), prefix: "Title", to: &parts, maxLength: 50)
        addNonEmptyAttribute(self.identifier(), prefix: "ID", to: &parts, maxLength: 50)
        addNonEmptyAttribute(self.domIdentifier(), prefix: "DOMId", to: &parts, maxLength: 50)
    }

    @MainActor
    private func addVerboseDetails(to parts: inout [String]) {
        if let value = self.value() {
            let valueStr = String(describing: value)
            if !valueStr.isEmpty, valueStr != "nil" {
                parts.append("Value: '\(valueStr.truncated(to: 80))'")
            }
        }

        addNonEmptyAttribute(self.help(), prefix: "Help", to: &parts, maxLength: 80)
    }

    @MainActor
    private func addNonEmptyAttribute(_ value: String?, prefix: String, to parts: inout [String], maxLength: Int) {
        if let value, !value.isEmpty {
            parts.append("\(prefix): '\(value.truncated(to: maxLength))'")
        }
    }

    @MainActor
    private func handleEmptyDescription() -> String {
        axDebugLog(
            "briefDescription: No descriptive attributes found, falling back to underlyingElement description.",
            details: ["element": AnyCodable(String(describing: self.underlyingElement))]
        )
        return String(describing: self.underlyingElement)
    }

    @MainActor
    private func formatShortDescription(_ parts: [String]) -> String {
        if let role = self.role() {
            "Role: \(role)"
        } else {
            parts.first ?? String(describing: self.underlyingElement)
        }
    }
}
