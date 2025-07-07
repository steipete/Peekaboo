import AppKit
import Foundation

enum ImageErrorHandler {
    static func handleError(_ error: Error, jsonOutput: Bool) {
        let captureError = self.extractCaptureError(from: error)
        self.logErrorDetails(captureError)

        if jsonOutput {
            self.handleJSONOutput(for: captureError)
        } else {
            self.handleStandardOutput(for: captureError)
        }
        // Don't call exit() here - let the caller handle process termination
    }

    private static func extractCaptureError(from error: Error) -> CaptureError {
        if let err = error as? CaptureError {
            err
        } else {
            .unknownError(error.localizedDescription)
        }
    }

    private static func logErrorDetails(_ captureError: CaptureError) {
        Logger.shared.debug("Image capture error: \(captureError)")

        // Log underlying errors if present
        switch captureError {
        case let .captureCreationFailed(underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying capture creation error: \(underlying)")
            }
        case let .windowCaptureFailed(underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying window capture error: \(underlying)")
            }
        case let .fileWriteError(_, underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying file write error: \(underlying)")
            }
        default:
            break
        }
    }

    private static func mapErrorCode(for captureError: CaptureError) -> ErrorCode {
        switch captureError {
        case .screenRecordingPermissionDenied:
            .PERMISSION_ERROR_SCREEN_RECORDING
        case .accessibilityPermissionDenied:
            .PERMISSION_ERROR_ACCESSIBILITY
        case .appNotFound:
            .APP_NOT_FOUND
        case .windowNotFound, .noWindowsFound:
            .WINDOW_NOT_FOUND
        case .fileWriteError:
            .FILE_IO_ERROR
        case .invalidArgument:
            .INVALID_ARGUMENT
        case .unknownError:
            .UNKNOWN_ERROR
        default:
            .CAPTURE_FAILED
        }
    }

    private static func getErrorDetails(for captureError: CaptureError) -> String {
        if case .appNotFound = captureError {
            let runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap(\.localizedName)
                .sorted()
                .joined(separator: ", ")
            return "Available applications: \(runningApps)"
        }
        return "Image capture operation failed"
    }

    private static func handleJSONOutput(for captureError: CaptureError) {
        let code = self.mapErrorCode(for: captureError)
        let details = self.getErrorDetails(for: captureError)

        outputError(
            message: captureError.localizedDescription,
            code: code,
            details: details)
    }

    private static func handleStandardOutput(for captureError: CaptureError) {
        var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
        print("Error: \(captureError.localizedDescription)", to: &localStandardErrorStream)
    }
}
