import Foundation
import PeekabooCore

// MARK: - Output Formatting Protocol

/// Protocol for commands that support both JSON and human-readable output
@MainActor
protocol OutputFormattable {
    var jsonOutput: Bool { get }
    var outputLogger: Logger { get }
}

extension OutputFormattable {
    /// Output data in appropriate format
    func output(_ data: some Codable, humanReadable: () -> Void) {
        if jsonOutput {
            outputSuccessCodable(data: data, logger: self.outputLogger)
        } else {
            humanReadable()
        }
    }

    /// Output success with optional data
    func outputSuccess(data: (some Codable)? = nil as Empty?) {
        if jsonOutput {
            if let data {
                outputSuccessCodable(data: data, logger: self.outputLogger)
            } else {
                outputJSON(JSONResponse(success: true), logger: self.outputLogger)
            }
        }
    }
}

// MARK: - Permission Checking

/// Check and require screen recording permission
@MainActor
func requireScreenRecordingPermission(services: any PeekabooServiceProviding) async throws {
    let hasPermission = await Task { @MainActor in
        await services.screenCapture.hasScreenRecordingPermission()
    }.value

    guard hasPermission else {
        throw CaptureError.screenRecordingPermissionDenied
    }
}

/// Check and require accessibility permission
@MainActor
func requireAccessibilityPermission(services: any PeekabooServiceProviding) throws {
    if !services.permissions.checkAccessibilityPermission() {
        throw CaptureError.accessibilityPermissionDenied
    }
}
