import Foundation
import ArgumentParser
import PeekabooCore
import CoreGraphics
import AppKit

// MARK: - Error Handling Protocol

/// Protocol for commands that need standardized error handling
protocol ErrorHandlingCommand {
    var jsonOutput: Bool { get }
}

extension ErrorHandlingCommand {
    /// Handle errors with appropriate output format
    func handleError(_ error: Error, customCode: ErrorCode? = nil) {
        if jsonOutput {
            let errorCode = customCode ?? mapErrorToCode(error)
            outputError(message: error.localizedDescription, code: errorCode)
        } else {
            // Get a more descriptive error message
            let errorMessage: String
            if let peekabooError = error as? PeekabooError {
                errorMessage = peekabooError.errorDescription ?? String(describing: error)
            } else if let captureError = error as? CaptureError {
                errorMessage = captureError.errorDescription ?? String(describing: error)
            } else if error.localizedDescription == "The operation couldn't be completed. (PeekabooCore.PeekabooError error 0.)" ||
                      error.localizedDescription == "Error" {
                // For generic errors, try to get more info
                errorMessage = String(describing: error)
            } else {
                errorMessage = error.localizedDescription
            }
            fputs("Error: \(errorMessage)\n", stderr)
        }
    }
    
    /// Map various error types to error codes
    private func mapErrorToCode(_ error: Error) -> ErrorCode {
        switch error {
        // PeekabooError mappings
        case let peekabooError as PeekabooError:
            return mapPeekabooErrorToCode(peekabooError)
            
        // CaptureError mappings
        case let captureError as CaptureError:
            return mapCaptureErrorToCode(captureError)
            
        // ArgumentParser ValidationError
        case is ArgumentParser.ValidationError:
            return .VALIDATION_ERROR
            
        // Default
        default:
            return .INTERNAL_SWIFT_ERROR
        }
    }
    
    private func mapPeekabooErrorToCode(_ error: PeekabooError) -> ErrorCode {
        switch error {
        case .appNotFound:
            return .APP_NOT_FOUND
        case .ambiguousAppIdentifier:
            return .AMBIGUOUS_APP_IDENTIFIER
        case .windowNotFound:
            return .WINDOW_NOT_FOUND
        case .elementNotFound:
            return .ELEMENT_NOT_FOUND
        case .sessionNotFound:
            return .SESSION_NOT_FOUND
        case .menuNotFound:
            return .MENU_BAR_NOT_FOUND
        case .menuItemNotFound:
            return .MENU_ITEM_NOT_FOUND
        case .permissionDeniedScreenRecording:
            return .PERMISSION_ERROR_SCREEN_RECORDING
        case .permissionDeniedAccessibility:
            return .PERMISSION_ERROR_ACCESSIBILITY
        case .captureTimeout, .timeout:
            return .TIMEOUT
        case .captureFailed, .clickFailed, .typeFailed:
            return .CAPTURE_FAILED
        case .invalidCoordinates:
            return .INVALID_COORDINATES
        case .fileIOError:
            return .FILE_IO_ERROR
        case .commandFailed:
            return .UNKNOWN_ERROR
        case .invalidInput:
            return .INVALID_INPUT
        case .encodingError:
            return .UNKNOWN_ERROR
        case .noAIProviderAvailable:
            return .MISSING_API_KEY
        case .aiProviderError:
            return .AGENT_ERROR
        case .serviceUnavailable:
            return .UNKNOWN_ERROR
        case .networkError:
            return .UNKNOWN_ERROR
        case .apiError:
            return .UNKNOWN_ERROR
        case .authenticationFailed:
            return .MISSING_API_KEY
        default:
            return .UNKNOWN_ERROR
        }
    }
    
    private func mapCaptureErrorToCode(_ error: CaptureError) -> ErrorCode {
        switch error {
        case .screenRecordingPermissionDenied, .permissionDeniedScreenRecording:
            return .PERMISSION_ERROR_SCREEN_RECORDING
        case .accessibilityPermissionDenied:
            return .PERMISSION_ERROR_ACCESSIBILITY
        case .noDisplaysAvailable, .noDisplaysFound:
            return .CAPTURE_FAILED
        case .invalidDisplayID, .invalidDisplayIndex:
            return .INVALID_ARGUMENT
        case .captureCreationFailed, .windowCaptureFailed, .captureFailed, .captureFailure:
            return .CAPTURE_FAILED
        case .windowNotFound, .noWindowsFound:
            return .WINDOW_NOT_FOUND
        case .windowTitleNotFound:
            return .WINDOW_NOT_FOUND
        case .fileWriteError, .fileIOError:
            return .FILE_IO_ERROR
        case .appNotFound:
            return .APP_NOT_FOUND
        case .invalidWindowIndexOld, .invalidWindowIndex:
            return .INVALID_ARGUMENT
        case .invalidArgument:
            return .INVALID_ARGUMENT
        case .unknownError:
            return .UNKNOWN_ERROR
        case .noFrontmostApplication:
            return .WINDOW_NOT_FOUND
        case .invalidCaptureArea:
            return .INVALID_ARGUMENT
        case .ambiguousAppIdentifier:
            return .AMBIGUOUS_APP_IDENTIFIER
        case .imageConversionFailed:
            return .CAPTURE_FAILED
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
    func output<T: Codable>(_ data: T, humanReadable: () -> Void) {
        if jsonOutput {
            outputSuccessCodable(data: data)
        } else {
            humanReadable()
        }
    }
    
    /// Output success with optional data
    func outputSuccess<T: Codable>(data: T? = nil as Empty?) {
        if jsonOutput {
            if let data = data {
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
        if let app = app {
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
        if let title = windowTitle {
            return windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = windowIndex, index < windows.count {
            return windows[index]
        } else {
            return windows.first
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