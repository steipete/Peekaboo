import Foundation

public enum DesktopObservationError: Error, LocalizedError, Equatable {
    case unsupportedTarget(String)
    case targetNotFound(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedTarget(target):
            "Desktop observation target is not supported yet: \(target)"
        case let .targetNotFound(target):
            "Desktop observation target was not found: \(target)"
        }
    }
}
