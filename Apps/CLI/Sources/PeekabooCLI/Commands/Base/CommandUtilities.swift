import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

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
        if let windowId {
            return .windowId(windowId)
        }
        if let app {
            if let index = windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowTitle {
                return .applicationAndTitle(app: app, title: title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }

    /// Select a window from a list based on options
    @MainActor
    func selectWindow(from windows: [ServiceWindowInfo]) -> ServiceWindowInfo? {
        if let windowId {
            windows.first(where: { $0.windowID == windowId })
        } else if let title = windowTitle {
            windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = windowIndex, index < windows.count {
            windows[index]
        } else {
            windows.first(where: { window in
                window.bounds.width >= 50 &&
                    window.bounds.height >= 50 &&
                    window.windowLevel == 0
            }) ?? windows.first
        }
    }

    /// Re-fetch the window info after a mutation so callers report fresh bounds.
    @MainActor
    func refetchWindowInfo(
        services: any PeekabooServiceProviding,
        logger: Logger,
        context: StaticString
    ) async -> ServiceWindowInfo? {
        guard let target = try? self.toWindowTarget() else {
            logger.warn("Failed to refetch window info (\(context)): invalid target")
            return nil
        }

        do {
            let refreshedWindows = try await WindowServiceBridge.listWindows(
                windows: services.windows,
                target: target
            )
            return self.selectWindow(from: refreshedWindows)
        } catch {
            logger.warn("Failed to refetch window info (\(context)): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Application Resolution

/// Marker protocol for commands that need to resolve applications using injected services.
protocol ApplicationResolver {}

extension ApplicationResolver {
    func resolveApplication(
        _ identifier: String,
        services: any PeekabooServiceProviding
    ) async throws -> ServiceApplicationInfo {
        do {
            return try await services.applications.findApplication(identifier: identifier)
        } catch {
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

        return .unknownError(self.localizedDescription)
    }
}
