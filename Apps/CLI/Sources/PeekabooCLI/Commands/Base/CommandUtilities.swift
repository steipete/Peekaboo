import AppKit
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

// MARK: - Error Handling Protocol

/// Protocol for commands that need standardized error handling
@MainActor
protocol ErrorHandlingCommand {
    var jsonOutput: Bool { get }
}

extension ErrorHandlingCommand {
    /// Handle errors with appropriate output format
    func handleError(_ error: any Error, customCode: ErrorCode? = nil) {
        // Handle errors with appropriate output format
        if jsonOutput {
            let errorCode = customCode ?? self.mapErrorToCode(error)
            let logger: Logger = if let formattable = self as? any OutputFormattable {
                formattable.outputLogger
            } else {
                Logger.shared
            }
            outputError(message: error.localizedDescription, code: errorCode, logger: logger)
        } else {
            // Get a more descriptive error message
            let errorMessage: String = if let peekabooError = error as? PeekabooError {
                peekabooError.errorDescription ?? String(describing: error)
            } else if let captureError = error as? CaptureError {
                captureError.errorDescription ?? String(describing: error)
            } else if error
                .localizedDescription == "The operation couldn't be completed. (PeekabooCore.PeekabooError error 0.)" ||
                error.localizedDescription == "Error" {
                // For generic errors, try to get more info
                String(describing: error)
            } else {
                error.localizedDescription
            }
            fputs("Error: \(errorMessage)\n", stderr)
        }
    }

    /// Map various error types to error codes
    private func mapErrorToCode(_ error: any Error) -> ErrorCode {
        // Map various error types to error codes
        switch error {
        // FocusError mappings
        case let focusError as FocusError:
            self.mapFocusErrorToCode(focusError)

        // PeekabooError mappings
        case let peekabooError as PeekabooError:
            self.mapPeekabooErrorToCode(peekabooError)

        // CaptureError mappings
        case let captureError as CaptureError:
            self.mapCaptureErrorToCode(captureError)

        // Commander ValidationError
        case is Commander.ValidationError:
            .VALIDATION_ERROR

        // Default
        default:
            .INTERNAL_SWIFT_ERROR
        }
    }

    private func mapPeekabooErrorToCode(_ error: PeekabooError) -> ErrorCode {
        if let lookupCode = self.lookupErrorCode(for: error) {
            return lookupCode
        }
        if let permissionCode = self.permissionErrorCode(for: error) {
            return permissionCode
        }
        if let timeoutCode = self.timeoutErrorCode(for: error) {
            return timeoutCode
        }
        if let automationCode = self.automationErrorCode(for: error) {
            return automationCode
        }
        if let inputCode = self.inputErrorCode(for: error) {
            return inputCode
        }
        if let credentialCode = self.credentialErrorCode(for: error) {
            return credentialCode
        }
        return .UNKNOWN_ERROR
    }

    private func lookupErrorCode(for error: PeekabooError) -> ErrorCode? {
        switch error {
        case .appNotFound:
            .APP_NOT_FOUND
        case .ambiguousAppIdentifier:
            .AMBIGUOUS_APP_IDENTIFIER
        case .windowNotFound:
            .WINDOW_NOT_FOUND
        case .elementNotFound:
            .ELEMENT_NOT_FOUND
        case .sessionNotFound:
            .SESSION_NOT_FOUND
        case .menuNotFound:
            .MENU_BAR_NOT_FOUND
        case .menuItemNotFound:
            .MENU_ITEM_NOT_FOUND
        default:
            nil
        }
    }

    private func permissionErrorCode(for error: PeekabooError) -> ErrorCode? {
        switch error {
        case .permissionDeniedScreenRecording:
            .PERMISSION_ERROR_SCREEN_RECORDING
        case .permissionDeniedAccessibility:
            .PERMISSION_ERROR_ACCESSIBILITY
        default:
            nil
        }
    }

    private func timeoutErrorCode(for error: PeekabooError) -> ErrorCode? {
        switch error {
        case .captureTimeout, .timeout:
            .TIMEOUT
        default:
            nil
        }
    }

    private func automationErrorCode(for error: PeekabooError) -> ErrorCode? {
        switch error {
        case .captureFailed, .clickFailed, .typeFailed:
            .CAPTURE_FAILED
        case .serviceUnavailable, .networkError, .apiError, .commandFailed, .encodingError:
            .UNKNOWN_ERROR
        default:
            nil
        }
    }

    private func inputErrorCode(for error: PeekabooError) -> ErrorCode? {
        switch error {
        case .invalidCoordinates:
            .INVALID_COORDINATES
        case .fileIOError:
            .FILE_IO_ERROR
        case .invalidInput:
            .INVALID_INPUT
        default:
            nil
        }
    }

    private func credentialErrorCode(for error: PeekabooError) -> ErrorCode? {
        switch error {
        case .noAIProviderAvailable, .authenticationFailed:
            .MISSING_API_KEY
        case .aiProviderError:
            .AGENT_ERROR
        default:
            nil
        }
    }

    private func mapCaptureErrorToCode(_ error: CaptureError) -> ErrorCode {
        switch error {
        case .screenRecordingPermissionDenied, .permissionDeniedScreenRecording:
            .PERMISSION_ERROR_SCREEN_RECORDING
        case .accessibilityPermissionDenied:
            .PERMISSION_ERROR_ACCESSIBILITY
        case .appleScriptPermissionDenied:
            .PERMISSION_ERROR_APPLESCRIPT
        case .noDisplaysAvailable, .noDisplaysFound:
            .CAPTURE_FAILED
        case .invalidDisplayID, .invalidDisplayIndex:
            .INVALID_ARGUMENT
        case .captureCreationFailed, .windowCaptureFailed, .captureFailed, .captureFailure:
            .CAPTURE_FAILED
        case .windowNotFound, .noWindowsFound:
            .WINDOW_NOT_FOUND
        case .windowTitleNotFound:
            .WINDOW_NOT_FOUND
        case .fileWriteError, .fileIOError:
            .FILE_IO_ERROR
        case .appNotFound:
            .APP_NOT_FOUND
        case .invalidWindowIndexOld, .invalidWindowIndex:
            .INVALID_ARGUMENT
        case .invalidArgument:
            .INVALID_ARGUMENT
        case .unknownError:
            .UNKNOWN_ERROR
        case .noFrontmostApplication:
            .WINDOW_NOT_FOUND
        case .invalidCaptureArea:
            .INVALID_ARGUMENT
        case .ambiguousAppIdentifier:
            .AMBIGUOUS_APP_IDENTIFIER
        case .imageConversionFailed:
            .CAPTURE_FAILED
        }
    }

    private func mapFocusErrorToCode(_ error: FocusError) -> ErrorCode {
        errorCode(for: error)
    }
}

func errorCode(for focusError: FocusError) -> ErrorCode {
    switch focusError {
    case .applicationNotRunning:
        .APP_NOT_FOUND
    case .focusVerificationTimeout, .timeoutWaitingForCondition:
        .TIMEOUT
    default:
        .WINDOW_NOT_FOUND
    }
}

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
        // Output data in appropriate format
        if jsonOutput {
            outputSuccessCodable(data: data, logger: self.outputLogger)
        } else {
            humanReadable()
        }
    }

    /// Output success with optional data
    func outputSuccess(data: (some Codable)? = nil as Empty?) {
        // Output success with optional data
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
func requireScreenRecordingPermission(services: PeekabooServices = PeekabooServices.shared) async throws {
    // Check and require screen recording permission
    let hasPermission = await Task { @MainActor in
        await services.screenCapture.hasScreenRecordingPermission()
    }.value

    guard hasPermission else {
        throw CaptureError.screenRecordingPermissionDenied
    }
}

/// Check and require accessibility permission
@MainActor
func requireAccessibilityPermission(services: PeekabooServices = PeekabooServices.shared) throws {
    if !services.permissions.checkAccessibilityPermission() {
        throw CaptureError.accessibilityPermissionDenied
    }
}

// MARK: - Service Bridges

enum AutomationServiceBridge {
    static func waitForElement(
        services: PeekabooServices,
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?
    ) async throws -> WaitForElementResult {
        try await Task { @MainActor in
            try await services.automation.waitForElement(target: target, timeout: timeout, sessionId: sessionId)
        }.value
    }

    static func click(
        services: PeekabooServices,
        target: ClickTarget,
        clickType: ClickType,
        sessionId: String?
    ) async throws {
        try await Task { @MainActor in
            try await services.automation.click(target: target, clickType: clickType, sessionId: sessionId)
        }.value
    }

    static func typeActions(
        services: PeekabooServices,
        request: TypeActionsRequest
    ) async throws -> TypeResult {
        try await Task { @MainActor in
            try await services.automation.typeActions(
                request.actions,
                typingDelay: request.typingDelay,
                sessionId: request.sessionId
            )
        }.value
    }

    static func scroll(
        services: PeekabooServices,
        request: ScrollRequest
    ) async throws {
        try await Task { @MainActor in
            try await services.automation.scroll(request)
        }.value
    }

    static func hotkey(services: PeekabooServices, keys: String, holdDuration: Int) async throws {
        try await Task { @MainActor in
            try await services.automation.hotkey(keys: keys, holdDuration: holdDuration)
        }.value
    }

    static func swipe(
        services: PeekabooServices,
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int
    ) async throws {
        try await Task { @MainActor in
            try await services.automation.swipe(from: from, to: to, duration: duration, steps: steps)
        }.value
    }

    static func drag(
        services: PeekabooServices,
        request: DragRequest
    ) async throws {
        try await Task { @MainActor in
            try await services.automation.drag(
                from: request.from,
                to: request.to,
                duration: request.duration,
                steps: request.steps,
                modifiers: request.modifiers
            )
        }.value
    }

    static func moveMouse(
        services: PeekabooServices,
        to point: CGPoint,
        duration: Int,
        steps: Int
    ) async throws {
        try await Task { @MainActor in
            try await services.automation.moveMouse(to: point, duration: duration, steps: steps)
        }.value
    }

    static func detectElements(
        services: PeekabooServices,
        imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?
    ) async throws -> ElementDetectionResult {
        try await Task { @MainActor in
            try await services.automation.detectElements(
                in: imageData,
                sessionId: sessionId,
                windowContext: windowContext
            )
        }.value
    }

    static func hasAccessibilityPermission(services: PeekabooServices) async -> Bool {
        await Task { @MainActor in
            await services.automation.hasAccessibilityPermission()
        }.value
    }
}

struct TypeActionsRequest: Sendable {
    let actions: [TypeAction]
    let typingDelay: Int
    let sessionId: String?
}

struct DragRequest: Sendable {
    let from: CGPoint
    let to: CGPoint
    let duration: Int
    let steps: Int
    let modifiers: String?
}

enum WindowServiceBridge {
    static func closeWindow(services: PeekabooServices, target: WindowTarget) async throws {
        try await Task { @MainActor in
            try await services.windows.closeWindow(target: target)
        }.value
    }

    static func minimizeWindow(services: PeekabooServices, target: WindowTarget) async throws {
        try await Task { @MainActor in
            try await services.windows.minimizeWindow(target: target)
        }.value
    }

    static func maximizeWindow(services: PeekabooServices, target: WindowTarget) async throws {
        try await Task { @MainActor in
            try await services.windows.maximizeWindow(target: target)
        }.value
    }

    static func moveWindow(services: PeekabooServices, target: WindowTarget, to origin: CGPoint) async throws {
        try await Task { @MainActor in
            try await services.windows.moveWindow(target: target, to: origin)
        }.value
    }

    static func resizeWindow(services: PeekabooServices, target: WindowTarget, to size: CGSize) async throws {
        try await Task { @MainActor in
            try await services.windows.resizeWindow(target: target, to: size)
        }.value
    }

    static func setWindowBounds(services: PeekabooServices, target: WindowTarget, bounds: CGRect) async throws {
        try await Task { @MainActor in
            try await services.windows.setWindowBounds(target: target, bounds: bounds)
        }.value
    }

    static func focusWindow(services: PeekabooServices, target: WindowTarget) async throws {
        try await Task { @MainActor in
            try await services.windows.focusWindow(target: target)
        }.value
    }

    static func listWindows(services: PeekabooServices, target: WindowTarget) async throws -> [ServiceWindowInfo] {
        try await Task { @MainActor in
            try await services.windows.listWindows(target: target)
        }.value
    }
}

enum MenuServiceBridge {
    static func listMenus(services: PeekabooServices, appIdentifier: String) async throws -> MenuStructure {
        try await Task { @MainActor in
            try await services.menu.listMenus(for: appIdentifier)
        }.value
    }

    static func listFrontmostMenus(services: PeekabooServices) async throws -> MenuStructure {
        try await Task { @MainActor in
            try await services.menu.listFrontmostMenus()
        }.value
    }

    static func listMenuExtras(services: PeekabooServices) async throws -> [MenuExtraInfo] {
        try await Task { @MainActor in
            try await services.menu.listMenuExtras()
        }.value
    }

    static func clickMenuItem(services: PeekabooServices, appIdentifier: String, itemPath: String) async throws {
        try await Task { @MainActor in
            try await services.menu.clickMenuItem(app: appIdentifier, itemPath: itemPath)
        }.value
    }

    static func clickMenuItemByName(services: PeekabooServices, appIdentifier: String, itemName: String) async throws {
        try await Task { @MainActor in
            try await services.menu.clickMenuItemByName(app: appIdentifier, itemName: itemName)
        }.value
    }

    static func clickMenuExtra(services: PeekabooServices, title: String) async throws {
        try await Task { @MainActor in
            try await services.menu.clickMenuExtra(title: title)
        }.value
    }

    static func listMenuBarItems(services: PeekabooServices) async throws -> [MenuBarItemInfo] {
        try await Task { @MainActor in
            try await services.menu.listMenuBarItems()
        }.value
    }

    static func clickMenuBarItem(named name: String, services: PeekabooServices) async throws -> PeekabooCore
    .ClickResult {
        try await Task<PeekabooCore.ClickResult, any Error> { @MainActor in
            try await services.menu.clickMenuBarItem(named: name)
        }.value
    }

    static func clickMenuBarItem(at index: Int, services: PeekabooServices) async throws -> PeekabooCore.ClickResult {
        try await Task<PeekabooCore.ClickResult, any Error> { @MainActor in
            try await services.menu.clickMenuBarItem(at: index)
        }.value
    }
}

enum DockServiceBridge {
    static func launchFromDock(services: PeekabooServices, appName: String) async throws {
        try await Task { @MainActor in
            try await services.dock.launchFromDock(appName: appName)
        }.value
    }

    static func findDockItem(services: PeekabooServices, name: String) async throws -> DockItem {
        try await Task { @MainActor in
            try await services.dock.findDockItem(name: name)
        }.value
    }

    static func rightClickDockItem(services: PeekabooServices, appName: String, menuItem: String?) async throws {
        try await Task { @MainActor in
            try await services.dock.rightClickDockItem(appName: appName, menuItem: menuItem)
        }.value
    }

    static func hideDock(services: PeekabooServices) async throws {
        try await Task { @MainActor in
            try await services.dock.hideDock()
        }.value
    }

    static func showDock(services: PeekabooServices) async throws {
        try await Task { @MainActor in
            try await services.dock.showDock()
        }.value
    }

    static func listDockItems(services: PeekabooServices, includeAll: Bool) async throws -> [DockItem] {
        try await Task { @MainActor in
            try await services.dock.listDockItems(includeAll: includeAll)
        }.value
    }
}

// MARK: - Timeout Utilities

/// Execute an async operation with a timeout
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    // Execute an async operation with a timeout
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
        // Create a window target from options
        if let app {
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
    @MainActor
    func selectWindow(from windows: [ServiceWindowInfo]) -> ServiceWindowInfo? {
        // Select a window from a list based on options
        if let title = windowTitle {
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
        services: PeekabooServices,
        logger: Logger,
        context: StaticString
    ) async -> ServiceWindowInfo? {
        guard let target = try? self.toWindowTarget() else {
            logger.warn("Failed to refetch window info (\(context)): invalid target")
            return nil
        }

        do {
            let refreshedWindows = try await WindowServiceBridge.listWindows(
                services: services,
                target: target
            )
            return self.selectWindow(from: refreshedWindows)
        } catch {
            logger.warn("Failed to refetch window info (\(context)): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Common Command Base Classes

// Note: WindowCommandBase is currently unused and has been commented out
// to avoid compilation issues with overlapping Commander option metadata.
/*
  /// Base struct for commands that work with windows
  struct WindowCommandBase: @MainActor MainActorAsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
  @Option(name: .shortAndLong, help: "Target application name or bundle ID")
  var app: String?

 @Option(name: .customShort("i", allowingJoined: false), help: "Window index (0-based)")
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

/// Marker protocol for commands that need to resolve applications using injected services.
protocol ApplicationResolver {}

extension ApplicationResolver {
    func resolveApplication(_ identifier: String, services: PeekabooServices) async throws -> ServiceApplicationInfo {
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
