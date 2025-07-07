// AXError+StringConversion.swift - String conversion for AXError

import ApplicationServices

extension AXError {
    var stringValue: String {
        switch self {
        case .success:
            return "success"
        case .failure:
            return "failure"
        case .apiDisabled:
            return "apiDisabled"
        case .invalidUIElement:
            return "invalidUIElement"
        case .invalidUIElementObserver:
            return "invalidUIElementObserver"
        case .cannotComplete:
            return "cannotComplete"
        case .attributeUnsupported:
            return "attributeUnsupported"
        case .actionUnsupported:
            return "actionUnsupported"
        case .notificationUnsupported:
            return "notificationUnsupported"
        case .notImplemented:
            return "notImplemented"
        case .notificationAlreadyRegistered:
            return "notificationAlreadyRegistered"
        case .notificationNotRegistered:
            return "notificationNotRegistered"
        case .noValue:
            return "noValue"
        case .parameterizedAttributeUnsupported:
            return "parameterizedAttributeUnsupported"
        case .illegalArgument:
            return "illegalArgument"
        case .notEnoughPrecision:
            return "notEnoughPrecision"
        @unknown default:
            return "unknownError (\(self.rawValue))"
        }
    }
}
