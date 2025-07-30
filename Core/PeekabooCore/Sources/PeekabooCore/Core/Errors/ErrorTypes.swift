import Foundation

// MARK: - Error Types

/// Errors that can occur during capture operations.
///
/// Comprehensive error enumeration covering all failure modes in screenshot capture,
/// window management, and file operations, with user-friendly error messages.
public enum CaptureError: Error, LocalizedError, Sendable {
    case noDisplaysAvailable
    case noDisplaysFound
    case screenRecordingPermissionDenied
    case accessibilityPermissionDenied
    case appleScriptPermissionDenied
    case invalidDisplayID
    case captureCreationFailed(Error?)
    case windowNotFound
    case windowTitleNotFound(String, String, String) // searchTerm, appName, availableTitles
    case windowCaptureFailed(Error?)
    case fileWriteError(String, Error?)
    case appNotFound(String)
    case invalidWindowIndexOld(Int)
    case invalidArgument(String)
    case unknownError(String)
    case noWindowsFound(String)
    case fileIOError(String)
    case captureFailure(String)
    case permissionDeniedScreenRecording
    case noFrontmostApplication
    case invalidCaptureArea
    case invalidDisplayIndex(Int, availableCount: Int)
    case ambiguousAppIdentifier(String, candidates: String)
    case invalidWindowIndex(Int, availableCount: Int)
    case captureFailed(String)
    case imageConversionFailed

    public var errorDescription: String? {
        switch self {
        case .noDisplaysAvailable:
            return "No displays available for capture."
        case .noDisplaysFound:
            return "No displays found on the system."
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required. " +
                "Please grant it in System Settings > Privacy & Security > Screen Recording."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for some operations. " +
                "Please grant it in System Settings > Privacy & Security > Accessibility."
        case .appleScriptPermissionDenied:
            return "AppleScript permission is required for automation. " +
                "Please grant it in System Settings > Privacy & Security > Automation."
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
        case let .invalidWindowIndexOld(index):
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
        case .permissionDeniedScreenRecording:
            return "Screen recording permission is required. Please grant it in System Settings > Privacy & Security > Screen Recording."
        case .noFrontmostApplication:
            return "No frontmost application found."
        case .invalidCaptureArea:
            return "Invalid capture area specified."
        case let .invalidDisplayIndex(index, count):
            return "Invalid display index \(index). Available displays: 0-\(count-1)."
        case let .ambiguousAppIdentifier(identifier, candidates):
            return "Multiple applications match '\(identifier)': \(candidates)."
        case let .invalidWindowIndex(index, count):
            return "Invalid window index \(index). Available windows: 0-\(count-1)."
        case let .captureFailed(message):
            return "Capture failed: \(message)"
        case .imageConversionFailed:
            return "Failed to convert captured image to desired format."
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .noDisplaysAvailable: 10
        case .noDisplaysFound: 32
        case .screenRecordingPermissionDenied: 11
        case .accessibilityPermissionDenied: 12
        case .appleScriptPermissionDenied: 33
        case .invalidDisplayID: 13
        case .captureCreationFailed: 14
        case .windowNotFound: 15
        case .windowTitleNotFound: 21
        case .windowCaptureFailed: 16
        case .fileWriteError: 17
        case .appNotFound: 18
        case .invalidWindowIndexOld: 19
        case .invalidArgument: 20
        case .unknownError: 1
        case .noWindowsFound: 7
        case .fileIOError: 22
        case .captureFailure: 23
        case .permissionDeniedScreenRecording: 24
        case .noFrontmostApplication: 25
        case .invalidCaptureArea: 26
        case .invalidDisplayIndex: 27
        case .ambiguousAppIdentifier: 28
        case .invalidWindowIndex: 29
        case .captureFailed: 30
        case .imageConversionFailed: 31
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