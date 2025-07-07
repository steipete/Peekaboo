import Foundation

// MARK: - Error Types

/// Errors that can occur during capture operations.
///
/// Comprehensive error enumeration covering all failure modes in screenshot capture,
/// window management, and file operations, with user-friendly error messages.
public enum CaptureError: Error, LocalizedError, Sendable {
    case noDisplaysAvailable
    case screenRecordingPermissionDenied
    case accessibilityPermissionDenied
    case invalidDisplayID
    case captureCreationFailed(Error?)
    case windowNotFound
    case windowTitleNotFound(String, String, String) // searchTerm, appName, availableTitles
    case windowCaptureFailed(Error?)
    case fileWriteError(String, Error?)
    case appNotFound(String)
    case invalidWindowIndex(Int)
    case invalidArgument(String)
    case unknownError(String)
    case noWindowsFound(String)
    case fileIOError(String)
    case captureFailure(String)

    public var errorDescription: String? {
        switch self {
        case .noDisplaysAvailable:
            return "No displays available for capture."
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required. " +
                "Please grant it in System Settings > Privacy & Security > Screen Recording."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for some operations. " +
                "Please grant it in System Settings > Privacy & Security > Accessibility."
        case .invalidDisplayID:
            return "Invalid display ID provided."
        case let .captureCreationFailed(underlyingError):
            var message = "Failed to create the screen capture."
            if let error = underlyingError {
                message += " \(error.localizedDescription)"
            }
            return message
        case .windowNotFound:
            return "The specified window could not be found."
        case let .windowTitleNotFound(searchTerm, appName, availableTitles):
            var message = "Window with title containing '\(searchTerm)' not found in \(appName)."
            if !availableTitles.isEmpty {
                message += " Available windows: \(availableTitles)."
            }
            message +=
                " Note: For URLs, try without the protocol (e.g., 'example.com:8080' instead of 'http://example.com:8080')."
            return message
        case let .windowCaptureFailed(underlyingError):
            var message = "Failed to capture the specified window."
            if let error = underlyingError {
                message += " \(error.localizedDescription)"
            }
            return message
        case let .fileWriteError(path, underlyingError):
            var message = "Failed to write capture file to path: \(path)."

            if let error = underlyingError {
                let errorString = error.localizedDescription
                if errorString.lowercased().contains("permission") {
                    message += " Permission denied - check that the directory is " +
                        "writable and the application has necessary permissions."
                } else if errorString.lowercased().contains("no such file") {
                    message += " Directory does not exist - ensure the parent directory exists."
                } else if errorString.lowercased().contains("no space") {
                    message += " Insufficient disk space available."
                } else {
                    message += " \(errorString)"
                }
            } else {
                message += " This may be due to insufficient permissions, missing directory, or disk space issues."
            }

            return message
        case let .appNotFound(identifier):
            return "Application with identifier '\(identifier)' not found or is not running."
        case let .invalidWindowIndex(index):
            return "Invalid window index: \(index)."
        case let .invalidArgument(message):
            return "Invalid argument: \(message)"
        case let .unknownError(message):
            return "An unexpected error occurred: \(message)"
        case let .noWindowsFound(appName):
            return "The '\(appName)' process is running, but no capturable windows were found."
        case let .fileIOError(message):
            return "File I/O error: \(message)"
        case let .captureFailure(message):
            return "Capture failed: \(message)"
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .noDisplaysAvailable: 10
        case .screenRecordingPermissionDenied: 11
        case .accessibilityPermissionDenied: 12
        case .invalidDisplayID: 13
        case .captureCreationFailed: 14
        case .windowNotFound: 15
        case .windowTitleNotFound: 21
        case .windowCaptureFailed: 16
        case .fileWriteError: 17
        case .appNotFound: 18
        case .invalidWindowIndex: 19
        case .invalidArgument: 20
        case .unknownError: 1
        case .noWindowsFound: 7
        case .fileIOError: 22
        case .captureFailure: 23
        }
    }
}

/// Standard result type for operations that may fail.
///
/// Provides a consistent format for returning success/failure status
/// along with output and error information.
public struct CommandResult: Codable, Sendable {
    public let success: Bool
    public let output: String?
    public let error: String?
    
    public init(success: Bool, output: String? = nil, error: String? = nil) {
        self.success = success
        self.output = output
        self.error = error
    }
}