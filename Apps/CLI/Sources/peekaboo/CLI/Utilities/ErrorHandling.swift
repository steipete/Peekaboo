import Foundation
import PeekabooCore

// MARK: - Common Error Handling

func handleApplicationError(_ error: ApplicationError, jsonOutput: Bool) {
    if jsonOutput {
        let errorCode: ErrorCode = switch error {
        case .notFound:
            .APP_NOT_FOUND
        case .ambiguous:
            .AMBIGUOUS_APP_IDENTIFIER
        case .ambiguousIdentifier:
            .AMBIGUOUS_APP_IDENTIFIER
        case .noFrontmostApplication:
            .APP_NOT_FOUND
        case .notInstalled:
            .APP_NOT_FOUND
        case .activationFailed:
            .INTERACTION_FAILED
        }

        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: errorCode))
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}

func handleGenericError(_ error: Error, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: .UNKNOWN_ERROR))
        outputJSON(response)
    } else {
        print("❌ Error: \(error.localizedDescription)")
    }
}

func handleValidationError(_ error: Error, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: .VALIDATION_ERROR))
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}

func handleCLIError(_ error: CLIError, jsonOutput: Bool) {
    if jsonOutput {
        let errorCode: ErrorCode = switch error {
        case .windowNotFound:
            .WINDOW_NOT_FOUND
        case .elementNotFound:
            .ELEMENT_NOT_FOUND
        case .interactionFailed:
            .INTERACTION_FAILED
        case .sessionNotFound, .noValidSessionFound:
            .SESSION_NOT_FOUND
        case .applicationNotFound:
            .APP_NOT_FOUND
        case .ambiguousAppIdentifier:
            .AMBIGUOUS_APP_IDENTIFIER
        case .noFrontmostApplication:
            .APP_NOT_FOUND
        case .timeout:
            .TIMEOUT
        case .operationFailed:
            .UNKNOWN_ERROR
        }

        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: errorCode))
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}