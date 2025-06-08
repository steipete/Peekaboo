import AppKit
import Foundation

enum ImageErrorHandler {
    static func handleError(_ error: Error, jsonOutput: Bool) {
        let captureError: CaptureError = if let err = error as? CaptureError {
            err
        } else {
            .unknownError(error.localizedDescription)
        }

        // Log the full error details for debugging
        Logger.shared.debug("Image capture error: \(error)")

        // If it's a CaptureError with an underlying error, log that too
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

        if jsonOutput {
            let code: ErrorCode = switch captureError {
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

            // Provide additional details for app not found errors
            var details: String?
            if case .appNotFound = captureError {
                let runningApps = NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .compactMap(\.localizedName)
                    .sorted()
                    .joined(separator: ", ")
                details = "Available applications: \(runningApps)"
            }

            outputError(
                message: captureError.localizedDescription,
                code: code,
                details: details ?? "Image capture operation failed"
            )
        } else {
            var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
            print("Error: \(captureError.localizedDescription)", to: &localStandardErrorStream)
        }
        // Don't call exit() here - let the caller handle process termination
    }
}
