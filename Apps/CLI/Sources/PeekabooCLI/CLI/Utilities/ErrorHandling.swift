import Foundation
import PeekabooCore
import PeekabooFoundation

// MARK: - Common Error Handling

private func emitError(
    message: String,
    code: ErrorCode,
    jsonOutput: Bool,
    prefix: String = "❌"
) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: message,
                code: code
            )
        )
        outputJSON(response)
    } else {
        print("\(prefix) \(message)")
    }
}

// ApplicationError has been replaced by PeekabooError
// Callers should use handleGenericError instead

func handleGenericError(_ error: Error, jsonOutput: Bool) {
    emitError(message: error.localizedDescription, code: .UNKNOWN_ERROR, jsonOutput: jsonOutput)
}

func handleValidationError(_ error: Error, jsonOutput: Bool) {
    emitError(message: error.localizedDescription, code: .VALIDATION_ERROR, jsonOutput: jsonOutput)
}
