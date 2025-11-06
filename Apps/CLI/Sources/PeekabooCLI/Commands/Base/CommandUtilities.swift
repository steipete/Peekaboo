import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

// MARK: - Error Handling Protocol

/// Protocol for commands that need standardized error handling
protocol ErrorHandlingCommand {
    var jsonOutput: Bool { get }
}

extension ErrorHandlingCommand {
    /// Handle errors with appropriate output format
    func handleError(_ error: Error, customCode: ErrorCode? = nil) {
        // Handle errors with appropriate output format
        if jsonOutput {
            let errorCode = customCode ?? self.mapErrorToCode(error)
            outputError(message: error.localizedDescription, code: errorCode)
        } else {
            // Get a more descriptive error message
            let errorMessage: String = if let peekabooError = error as? PeekabooError {
                peekabooError.errorDescription ?? String(describing: error)
            } else if let captureError = error as? CaptureError {
                captureError.errorDescription ?? String(describing: error)
            } else if error
                .localizedDescription == "The operation couldn't be completed. (PeekabooCore.PeekabooError error 0.)" ||
                error.localizedDescription == "Error" {
                // For generic errors, try to get more info
                String(describing: error)
            } else {
                error.localizedDescription
            }
            fputs("Error: \(errorMessage)\n", stderr)
        }
    }

    /// Map various error types to error codes
    private func mapErrorToCode(_ error: Error) -> ErrorCode {
        // Map various error types to error codes
        switch error {
        // PeekabooError mappings
        case let peekabooError as PeekabooError:
            self.mapPeekabooErrorToCode(peekabooError)

        // CaptureError mappings
        case let captureError as CaptureError:
            self.mapCaptureErrorToCode(captureError)

        // ArgumentParser ValidationError
        case is ArgumentParser.ValidationError:
            .VALIDATION_ERROR

        // Default
        default:
            .INTERNAL_SWIFT_ERROR
        }
    }

    private func mapPeekabooErrorToCode(_ error: PeekabooError) -> ErrorCode {
        switch error {
        case .appNotFound:
            .APP_NOT_FOUND
        case .ambiguousAppIdentifier:
            .AMBIGUOUS_APP_IDENTIFIER
        case .windowNotFound:
            .WINDOW_NOT_FOUND
        case .elementNotFound:
            .ELEMENT_NOT_FOUND
        case .sessionNotFound:
            .SESSION_NOT_FOUND
        case .menuNotFound:
            .MENU_BAR_NOT_FOUND
        case .menuItemNotFound:
            .MENU_ITEM_NOT_FOUND
        case .permissionDeniedScreenRecording:
            .PERMISSION_ERROR_SCREEN_RECORDING
        case .permissionDeniedAccessibility:
            .PERMISSION_ERROR_ACCESSIBILITY
        case .captureTimeout, .timeout:
            .TIMEOUT
        case .captureFailed, .clickFailed, .typeFailed:
            .CAPTURE_FAILED
        case .invalidCoordinates:
            .INVALID_COORDINATES
        case .fileIOError:
            .FILE_IO_ERROR
        case .commandFailed:
            .UNKNOWN_ERROR
        case .invalidInput:
            .INVALID_INPUT
        case .encodingError:
            .UNKNOWN_ERROR
        case .noAIProviderAvailable:
            .MISSING_API_KEY
        case .aiProviderError:
            .AGENT_ERROR
        case .serviceUnavailable:
            .UNKNOWN_ERROR
        case .networkError:
            .UNKNOWN_ERROR
        case .apiError:
            .UNKNOWN_ERROR
        case .authenticationFailed:
            .MISSING_API_KEY
        default:
            .UNKNOWN_ERROR
        }
    }

    private func mapCaptureErrorToCode(_ error: CaptureError) -> ErrorCode {
        switch error {
        case .screenRecordingPermissionDenied, .permissionDeniedScreenRecording:
            .PERMISSION_ERROR_SCREEN_RECORDING
        case .accessibilityPermissionDenied:
            .PERMISSION_ERROR_ACCESSIBILITY
        case .appleScriptPermissionDenied:
            .PERMISSION_ERROR_APPLESCRIPT
        case .noDisplaysAvailable, .noDisplaysFound:
            .CAPTURE_FAILED
        case .invalidDisplayID, .invalidDisplayIndex:
            .INVALID_ARGUMENT
        case .captureCreationFailed, .windowCaptureFailed, .captureFailed, .captureFailure:
            .CAPTURE_FAILED
        case .windowNotFound, .noWindowsFound:
            .WINDOW_NOT_FOUND
        case .windowTitleNotFound:
            .WINDOW_NOT_FOUND
        case .fileWriteError, .fileIOError:
            .FILE_IO_ERROR
        case .appNotFound:
            .APP_NOT_FOUND
        case .invalidWindowIndexOld, .invalidWindowIndex:
            .INVALID_ARGUMENT
        case .invalidArgument:
            .INVALID_ARGUMENT
        case .unknownError:
            .UNKNOWN_ERROR
        case .noFrontmostApplication:
            .WINDOW_NOT_FOUND
        case .invalidCaptureArea:
            .INVALID_ARGUMENT
        case .ambiguousAppIdentifier:
            .AMBIGUOUS_APP_IDENTIFIER
        case .imageConversionFailed:
            .CAPTURE_FAILED
        }
    }
}

// MARK: - Output Formatting Protocol

/// Protocol for commands that support both JSON and human-readable output
protocol OutputFormattable {
    var jsonOutput: Bool { get }
}

extension OutputFormattable {
    /// Output data in appropriate format
    func output(_ data: some Codable, humanReadable: () -> Void) {
        // Output data in appropriate format
        if jsonOutput {
            outputSuccessCodable(data: data)
        } else {
            humanReadable()
        }
    }

    /// Output success with optional data
    func outputSuccess(data: (some Codable)? = nil as Empty?) {
        // Output success with optional data
        if jsonOutput {
            if let data {
                outputSuccessCodable(data: data)
            } else {
                outputJSON(JSONResponse(success: true))
            }
        }
    }
}

// MARK: - Permission Checking

/// Check and require screen recording permission
func requireScreenRecordingPermission() async throws {
    // Check and require screen recording permission
    guard await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission() else {
        throw CaptureError.screenRecordingPermissionDenied
    }
}

/// Check and require accessibility permission
@MainActor
func requireAccessibilityPermission() throws {
    if !PeekabooServices.shared.permissions.checkAccessibilityPermission() {
        throw CaptureError.accessibilityPermissionDenied
    }
}

// MARK: - Timeout Utilities

/// Execute an async operation with a timeout
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    // Execute an async operation with a timeout
    let task = Task {
        try await operation()
    }

    let timeoutTask = Task {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        task.cancel()
    }

    do {
        let result = try await task.value
        timeoutTask.cancel()
        return result
    } catch {
        timeoutTask.cancel()
        if task.isCancelled {
            throw CaptureError.captureFailure("Operation timed out after \(seconds) seconds")
        }
        throw error
    }
}

// MARK: - Window Target Extensions

extension WindowIdentificationOptions {
    /// Create a window target from options
    func createTarget() -> WindowTarget {
        // Create a window target from options
        if let app {
            if let index = windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowTitle {
                return .title(title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }

    /// Select a window from a list based on options
    func selectWindow(from windows: [ServiceWindowInfo]) -> ServiceWindowInfo? {
        // Select a window from a list based on options
        if let title = windowTitle {
            windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = windowIndex, index < windows.count {
            windows[index]
        } else {
            windows.first
        }
    }
}

// MARK: - Common Command Base Classes

// Note: WindowCommandBase is currently unused and has been commented out
// to avoid compilation issues with ArgumentParser Option types.
/*
 /// Base struct for commands that work with windows
 struct WindowCommandBase: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
 @Option(name: .shortAndLong, help: "Target application name or bundle ID")
 var app: String?

 @Option(name: .short, help: "Window index (0-based)")
 var windowIndex: Int?

 @Option(name: .long, help: "Window title (partial match)")
 var windowTitle: String?

 @Flag(name: .long, help: "Output in JSON format")
 var jsonOutput = false

 /// Get window identification options
 var windowOptions: WindowIdentificationOptions {
 WindowIdentificationOptions(
 app: app,
 windowTitle: windowTitle,
 windowIndex: windowIndex
 )
 }
 }
 */

// MARK: - Application Resolution

/// Protocol for commands that need to resolve applications
protocol ApplicationResolver {
    func resolveApplication(_ identifier: String) async throws -> ServiceApplicationInfo
}

extension ApplicationResolver {
    func resolveApplication(_ identifier: String) async throws -> ServiceApplicationInfo {
        do {
            return try await PeekabooServices.shared.applications.findApplication(identifier: identifier)
        } catch {
            // Provide more specific error messages if needed
            if identifier.lowercased() == "frontmost" {
                var message = "Application 'frontmost' not found"
                message += "\n\n💡 Note: 'frontmost' is not a valid app name. To work with the currently active app:"
                message += "\n  • Use `see` without arguments to capture current screen"
                message += "\n  • Use `app focus` with a specific app name"
                message += "\n  • Use `--app frontmost` with image/see commands to capture the active window"
                throw PeekabooError.appNotFound(identifier)
            }
            throw error
        }
    }
}

// MARK: - Capture Error Extensions

extension Error {
    /// Convert any error to a CaptureError if possible
    var asCaptureError: CaptureError {
        if let captureError = self as? CaptureError {
            return captureError
        }

        // Map PeekabooError to CaptureError
        if let peekabooError = self as? PeekabooError {
            switch peekabooError {
            case let .appNotFound(identifier):
                return .appNotFound(identifier)
            case .windowNotFound:
                return .windowNotFound
            default:
                return .unknownError(self.localizedDescription)
            }
        }

        // Default
        return .unknownError(self.localizedDescription)
    }
}
