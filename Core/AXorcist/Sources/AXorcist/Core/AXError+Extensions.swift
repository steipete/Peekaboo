//
//  AXError+Extensions.swift
//  AXorcist
//
//  Extends AXError with helpful utilities
//

import ApplicationServices
import Foundation

// Create a custom error type that wraps AXError
public struct AccessibilitySystemError: Error, LocalizedError {
    public let axError: AXError

    public init(_ axError: AXError) {
        self.axError = axError
    }

    public var errorDescription: String? {
        switch axError {
        case .success:
            return "No error (success)"
        case .apiDisabled:
            return "Accessibility API is disabled"
        case .invalidUIElement:
            return "Invalid UI element"
        case .attributeUnsupported:
            return "Attribute is not supported"
        case .parameterizedAttributeUnsupported:
            return "Parameterized attribute is not supported"
        case .actionUnsupported:
            return "Action is not supported"
        case .noValue:
            return "No value available"
        case .cannotComplete:
            return "Cannot complete operation"
        case .notImplemented:
            return "Not implemented"
        case .notificationUnsupported:
            return "Notification is not supported"
        case .notificationAlreadyRegistered:
            return "Notification is already registered"
        case .notificationNotRegistered:
            return "Notification is not registered"
        case .invalidUIElementObserver:
            return "Invalid UI element observer"
        case .notEnoughPrecision:
            return "Not enough precision"
        case .illegalArgument:
            return "Illegal argument"
        case .failure:
            return "Operation failed"
        @unknown default:
            return "Unknown AXError: \(axError.rawValue)"
        }
    }
}

extension AXError {
    /// Throws if the AXError is not .success
    @usableFromInline func throwIfError() throws {
        if self != .success {
            throw AccessibilitySystemError(self)
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

    /// Provides a localized description for AXError
    public var localizedDescription: String {
        AccessibilitySystemError(self).errorDescription ?? "Unknown AXError: \(self.rawValue)"
    }
}
