import CoreGraphics
import Foundation
import PeekabooFoundation

@MainActor
extension WindowManagementService {
    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        var windowBounds: CGRect?

        let success = try await performWindowOperation(target: target) { window in
            if let currentPosition = window.position(), let size = window.size() {
                windowBounds = CGRect(origin: currentPosition, size: size)
            }

            let result = window.moveWindow(to: position)
            if let bounds = windowBounds {
                self.showWindowOperation(.move, bounds: CGRect(origin: position, size: bounds.size))
            }
            return result
        }

        if !success {
            throw OperationError.interactionFailed(
                action: "move window",
                reason: "Window move operation failed")
        }
    }

    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        var windowBounds: CGRect?

        let resizeDescription = "target=\(target), size=(width: \(size.width), height: \(size.height))"
        self.logger.info("Starting resize window operation: \(resizeDescription)")
        let startTime = Date()

        let success = try await performWindowOperation(target: target) { window in
            if let position = window.position() {
                windowBounds = CGRect(origin: position, size: size)
            }

            let result = window.resizeWindow(to: size)
            self.showWindowOperation(.resize, bounds: windowBounds)
            return result
        }

        let elapsed = Date().timeIntervalSince(startTime)
        self.logger.info("Resize window operation completed in \(elapsed)s")

        if !success {
            throw OperationError.interactionFailed(
                action: "resize window",
                reason: "Window resize operation failed")
        }
    }

    public func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        let success = try await performWindowOperation(target: target) { window in
            let result = window.setWindowBounds(bounds)
            self.showWindowOperation(.setBounds, bounds: bounds)
            return result
        }

        if !success {
            throw OperationError.interactionFailed(
                action: "set window bounds",
                reason: "Window bounds operation failed")
        }
    }
}
