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
            fputs("Error: \(error.localizedDescription)\n", stderr)
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
            
        // NotFoundError mappings
        case let notFoundError as NotFoundError:
            switch notFoundError {
            case .application:
                return .APP_NOT_FOUND
            case .window:
                return .WINDOW_NOT_FOUND
            case .element:
                return .ELEMENT_NOT_FOUND
            case .session:
                return .SESSION_NOT_FOUND
            }
            
        // ValidationError mappings
        case let validationError as ValidationError:
            switch validationError {
            case .invalidImageFormat:
                return .INVALID_IMAGE_FORMAT
            case .ambiguousAppIdentifier:
                return .AMBIGUOUS_APP_IDENTIFIER
            default:
                return .VALIDATION_ERROR
            }
            
        // CLIError mappings
        case let cliError as CLIError:
            return mapCLIErrorToCode(cliError)
            
        // Default
        default:
            return .INTERNAL_SWIFT_ERROR
        }
    }
    
    private func mapPeekabooErrorToCode(_ error: PeekabooError) -> ErrorCode {
        switch error {
        case .invalidImageFormat:
            return .INVALID_IMAGE_FORMAT
        case .ambiguousApplication:
            return .AMBIGUOUS_APP_IDENTIFIER
        case .applicationNotFound:
            return .APP_NOT_FOUND
        case .invalidCoordinates:
            return .VALIDATION_ERROR
        case .invalidDimensions:
            return .VALIDATION_ERROR
        case .invalidDisplayIndex:
            return .VALIDATION_ERROR
        case .invalidWindowIndex:
            return .VALIDATION_ERROR
        case .accessibilityError:
            return .ACCESSIBILITY_ERROR
        default:
            return .UNKNOWN_ERROR
        }
    }
    
    private func mapCaptureErrorToCode(_ error: CaptureError) -> ErrorCode {
        switch error {
        case .screenRecordingPermissionDenied:
            return .SCREEN_RECORDING_PERMISSION_DENIED
        case .accessibilityPermissionDenied:
            return .ACCESSIBILITY_PERMISSION_DENIED
        case .captureConfigurationError:
            return .CAPTURE_CONFIGURATION_ERROR
        case .captureStreamNotFound:
            return .CAPTURE_STREAM_NOT_FOUND
        case .invalidImageFormat:
            return .INVALID_IMAGE_FORMAT
        case .fileWriteError:
            return .FILE_WRITE_ERROR
        case .timeout:
            return .TIMEOUT
        case .invalidFrameInfo:
            return .CAPTURE_CONFIGURATION_ERROR
        case .modernCaptureNotSupported:
            return .MODERN_CAPTURE_NOT_SUPPORTED
        case .screenshotCaptureFailed:
            return .SCREENSHOT_CAPTURE_FAILED
        case .invalidAppReference:
            return .INVALID_APP_REFERENCE
        case .windowInfoUnavailable:
            return .WINDOW_INFO_UNAVAILABLE
        }
    }
    
    private func mapCLIErrorToCode(_ error: CLIError) -> ErrorCode {
        switch error {
        case .windowNotFound:
            return .WINDOW_NOT_FOUND
        case .elementNotFound:
            return .ELEMENT_NOT_FOUND
        case .interactionFailed:
            return .INTERACTION_FAILED
        case .sessionNotFound, .noValidSessionFound:
            return .SESSION_NOT_FOUND
        case .applicationNotFound:
            return .APP_NOT_FOUND
        case .ambiguousAppIdentifier:
            return .AMBIGUOUS_APP_IDENTIFIER
        case .noFrontmostApplication:
            return .APP_NOT_FOUND
        case .timeout:
            return .TIMEOUT
        case .operationFailed:
            return .UNKNOWN_ERROR
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
    func output<T: Encodable>(_ data: T, humanReadable: () -> Void) {
        if jsonOutput {
            outputSuccessCodable(data: data)
        } else {
            humanReadable()
        }
    }
    
    /// Output success with optional data
    func outputSuccess<T: Encodable>(data: T? = nil as Empty?) {
        if jsonOutput {
            if let data = data {
                outputSuccessCodable(data: data)
            } else {
                outputJSON(JSONResponse(success: true))
            }
        }
    }
}

// Empty type for when there's no data
struct Empty: Encodable {}

// MARK: - Permission Checking

/// Check and require screen recording permission
func requireScreenRecordingPermission() async throws {
    guard await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission() else {
        throw CaptureError.screenRecordingPermissionDenied
    }
}

/// Check and require accessibility permission
func requireAccessibilityPermission() throws {
    if !PeekabooServices.shared.permissions.checkAccessibilityPermission() {
        throw CaptureError.accessibilityPermissionDenied
    }
}

// MARK: - Timeout Utilities

/// Execute an async operation with a timeout
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
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
            throw CaptureError.timeout(seconds)
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

/// Base class for commands that work with windows
class WindowCommandBase: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
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
            windowIndex: windowIndex,
            windowTitle: windowTitle
        )
    }
}

// MARK: - Application Resolution

/// Protocol for commands that need to resolve applications
protocol ApplicationResolvable {
    func resolveApplication(_ identifier: String) async throws -> ServiceApplicationInfo
}

extension ApplicationResolvable {
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
        
        // Map common errors
        if let notFoundError = self as? NotFoundError {
            switch notFoundError {
            case .application(let identifier):
                return .invalidAppReference("Application not found: \(identifier)")
            case .window:
                return .windowInfoUnavailable("Window not found")
            default:
                break
            }
        }
        
        // Default
        return .captureConfigurationError(self.localizedDescription)
    }
}