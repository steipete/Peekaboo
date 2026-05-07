import CoreGraphics
import Foundation

@MainActor
@_spi(Testing) public protocol ScreenRecordingPermissionEvaluating: Sendable {
    func hasPermission(logger: CategoryLogger) async -> Bool
}

struct ScreenRecordingPermissionChecker: ScreenRecordingPermissionEvaluating {
    func hasPermission(logger: CategoryLogger) async -> Bool {
        let preflightResult = CGPreflightScreenCaptureAccess()
        if preflightResult {
            return true
        }

        // CGPreflightScreenCaptureAccess is unreliable for CLI tools. It often returns false even when permission is
        // granted because TCC tracks by code signature and the check can fail after rebuilds or for non-.app bundles.
        logger.debug("CGPreflightScreenCaptureAccess returned false, probing SCShareableContent")
        do {
            _ = try await ScreenCaptureKitCaptureGate.currentShareableContent()
            logger.info("Screen recording permission granted (SCShareableContent probe)")
            return true
        } catch {
            if let delay = ScreenCaptureKitTransientError.retryDelayNanoseconds(after: error) {
                logger.warning(
                    "Screen recording permission probe hit transient ScreenCaptureKit denial; retrying once")
                try? await Task.sleep(nanoseconds: delay)
                do {
                    _ = try await ScreenCaptureKitCaptureGate.currentShareableContent()
                    logger.info("Screen recording permission granted (SCShareableContent retry)")
                    return true
                } catch {
                    logger.warning("Screen recording permission retry failed: \(error)")
                }
            }
            logger.warning("Screen recording permission not granted (SCShareableContent probe failed: \(error))")
            return false
        }
    }
}

@MainActor
struct ScreenCapturePermissionGate {
    private let evaluator: any ScreenRecordingPermissionEvaluating

    init(evaluator: any ScreenRecordingPermissionEvaluating) {
        self.evaluator = evaluator
    }

    func hasPermission(logger: CategoryLogger) async -> Bool {
        await self.evaluator.hasPermission(logger: logger)
    }

    func requirePermission(logger: CategoryLogger, correlationId: String) async throws {
        logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await self.hasPermission(logger: logger) else {
            logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }
    }
}
