// Element+Actions.swift - Action-related methods for Element

import ApplicationServices
import Foundation

// GlobalAXLogger should be available

// Action-related extension for Element
public extension Element {
    // MARK: - Actions

    @MainActor
    func isActionSupported(_ actionName: String) -> Bool { // Removed logging params
        // self.supportedActions() is refactored and uses GlobalAXLogger internally
        // Assumes self.supportedActions() is refactored in Element+Properties.swift
        if let actions = self.supportedActions() {
            return actions.contains(actionName)
        }
        return false
    }

    @MainActor
    @discardableResult
    func performAction(_ actionName: Attribute<String>) throws -> Element { // Removed logging params
        // self.briefDescription() is refactored and uses GlobalAXLogger internally
        // Assumes self.briefDescription() is refactored in Element+Description.swift
        let descForLog = self.briefDescription(option: .smart)
        axDebugLog("Attempting to perform action '\(actionName.rawValue)' on element: \(descForLog)")

        let error = AXUIElementPerformAction(self.underlyingElement, actionName.rawValue as CFString)

        // Use new error extension
        try error.throwIfError()

        axInfoLog("Successfully performed action '\(actionName.rawValue)' on element: \(descForLog)")
        return self
    }

    @MainActor
    @discardableResult
    func performAction(_ actionName: String) throws -> Element { // Removed logging params
        let descForLog = self.briefDescription(option: .smart)
        axDebugLog("Attempting to perform action '\(actionName)' on element: \(descForLog)")

        let error = AXUIElementPerformAction(self.underlyingElement, actionName as CFString)

        // Use new error extension
        try error.throwIfError()

        axInfoLog("Successfully performed action '\(actionName)' on element: \(descForLog)")
        return self
    }

    /// Modern enum-based performAction method with cleaner syntax
    /// Example: try element.performAction(.raise)
    @MainActor
    @discardableResult
    func performAction(_ action: AXAction) throws -> Element {
        try performAction(action.rawValue)
    }
}
