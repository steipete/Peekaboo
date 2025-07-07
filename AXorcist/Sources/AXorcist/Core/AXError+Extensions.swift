//
//  AXError+Extensions.swift
//  AXorcist
//
//  Extends AXError with helpful utilities
//

import ApplicationServices
import Foundation

extension AXError: @retroactive Error {}

extension AXError {
    /// Throws if the AXError is not .success
    @usableFromInline func throwIfError() throws {
        if self != .success {
            throw self
        }
    }

    /// Converts AXError to AccessibilityError with appropriate context
    func toAccessibilityError(context: String? = nil) -> AccessibilityError {
        switch self {
        case .success:
            .genericError("Unexpected success in error context")
        case .apiDisabled:
            .apiDisabled
        case .invalidUIElement:
            .invalidElement
        case .attributeUnsupported:
            .attributeUnsupported(attribute: context ?? "Unknown attribute", elementDescription: nil)
        case .actionUnsupported:
            .actionUnsupported(action: context ?? "Unknown action", elementDescription: nil)
        case .noValue:
            .attributeNotReadable(attribute: context ?? "Attribute has no value", elementDescription: nil)
        case .cannotComplete:
            .genericError(context ?? "Cannot complete operation")
        default:
            .unknownAXError(self)
        }
    }
}
