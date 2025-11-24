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
func requireScreenRecordingPermission(services: any PeekabooServiceProviding) async throws {
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
func requireAccessibilityPermission(services: any PeekabooServiceProviding) throws {
    if !services.permissions.checkAccessibilityPermission() {
        throw CaptureError.accessibilityPermissionDenied
    }
}

// MARK: - Service Bridges

enum AutomationServiceBridge {
    static func waitForElement(
        automation: any UIAutomationServiceProtocol,
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?
    ) async throws -> WaitForElementResult {
        let result = try await Task { @MainActor in
            try await automation.waitForElement(target: target, timeout: timeout, sessionId: sessionId)
        }.value

        if !result.warnings.isEmpty {
            Logger.shared.debug(
                "waitForElement warnings: \(result.warnings.joined(separator: ","))",
                category: "Automation"
            )
        }

        return result
    }

    static func click(
        automation: any UIAutomationServiceProtocol,
        target: ClickTarget,
        clickType: ClickType,
        sessionId: String?
    ) async throws {
        try await Task { @MainActor in
            try await automation.click(target: target, clickType: clickType, sessionId: sessionId)
        }.value
    }

    static func typeActions(
        automation: any UIAutomationServiceProtocol,
        request: TypeActionsRequest
    ) async throws -> TypeResult {
        try await Task { @MainActor in
            try await automation.typeActions(
                request.actions,
                cadence: request.cadence,
                sessionId: request.sessionId
            )
        }.value
    }

    static func scroll(
        automation: any UIAutomationServiceProtocol,
        request: ScrollRequest
    ) async throws {
        try await Task { @MainActor in
            try await automation.scroll(request)
        }.value
    }

    static func hotkey(automation: any UIAutomationServiceProtocol, keys: String, holdDuration: Int) async throws {
        try await Task { @MainActor in
            try await automation.hotkey(keys: keys, holdDuration: holdDuration)
        }.value
    }

    // swiftlint:disable:next function_parameter_count
    static func swipe(
        automation: any UIAutomationServiceProtocol,
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile
    ) async throws {
        try await Task { @MainActor in
            try await automation.swipe(from: from, to: to, duration: duration, steps: steps, profile: profile)
        }.value
    }

    static func drag(
        automation: any UIAutomationServiceProtocol,
        request: DragRequest
    ) async throws {
        try await Task { @MainActor in
            try await automation.drag(
                from: request.from,
                to: request.to,
                duration: request.duration,
                steps: request.steps,
                modifiers: request.modifiers,
                profile: request.profile
            )
        }.value
    }

    static func moveMouse(
        automation: any UIAutomationServiceProtocol,
        to point: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile
    ) async throws {
        try await Task { @MainActor in
            try await automation.moveMouse(to: point, duration: duration, steps: steps, profile: profile)
        }.value
    }

    static func detectElements(
        automation: any UIAutomationServiceProtocol,
        imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?
    ) async throws -> ElementDetectionResult {
        try await Task { @MainActor in
            try await automation.detectElements(
                in: imageData,
                sessionId: sessionId,
                windowContext: windowContext
            )
        }.value
    }

    static func hasAccessibilityPermission(automation: any UIAutomationServiceProtocol) async -> Bool {
        await Task { @MainActor in
            await automation.hasAccessibilityPermission()
        }.value
    }
}

struct TypeActionsRequest: Sendable {
    let actions: [TypeAction]
    let cadence: TypingCadence
    let sessionId: String?
}

struct DragRequest: Sendable {
    let from: CGPoint
    let to: CGPoint
    let duration: Int
    let steps: Int
    let modifiers: String?
    let profile: MouseMovementProfile
}

enum CursorMovementProfileSelection: String {
    case linear
    case human
}

struct CursorMovementParameters {
    let profile: MouseMovementProfile
    let duration: Int
    let steps: Int
    let smooth: Bool
    let profileName: String
}

enum CursorMovementResolver {
    // swiftlint:disable:next function_parameter_count
    static func resolve(
        selection: CursorMovementProfileSelection,
        durationOverride: Int?,
        stepsOverride: Int?,
        baseSmooth: Bool,
        distance: CGFloat,
        defaultDuration: Int,
        defaultSteps: Int
    ) -> CursorMovementParameters {
        switch selection {
        case .linear:
            let resolvedDuration = durationOverride ?? (baseSmooth ? defaultDuration : 0)
            let resolvedSteps = baseSmooth ? max(stepsOverride ?? defaultSteps, 1) : 1
            return CursorMovementParameters(
                profile: .linear,
                duration: resolvedDuration,
                steps: resolvedSteps,
                smooth: baseSmooth,
                profileName: selection.rawValue
            )
        case .human:
            let resolvedDuration = durationOverride ?? Self.humanDuration(for: distance)
            let resolvedSteps = max(stepsOverride ?? Self.humanSteps(for: distance), 30)
            return CursorMovementParameters(
                profile: .human(),
                duration: resolvedDuration,
                steps: resolvedSteps,
                smooth: true,
                profileName: selection.rawValue
            )
        }
    }

    private static func humanDuration(for distance: CGFloat) -> Int {
        let distanceFactor = log2(Double(distance) + 1) * 90
        let perPixel = Double(distance) * 0.45
        let estimate = 280 + distanceFactor + perPixel
        return min(max(Int(estimate), 300), 1700)
    }

    private static func humanSteps(for distance: CGFloat) -> Int {
        let scaled = Int(distance * 0.35)
        return min(max(scaled, 40), 140)
    }
}

enum WindowServiceBridge {
    static func closeWindow(windows: any WindowManagementServiceProtocol, target: WindowTarget) async throws {
        try await Task { @MainActor in
            try await windows.closeWindow(target: target)
        }.value
    }

    static func minimizeWindow(windows: any WindowManagementServiceProtocol, target: WindowTarget) async throws {
        try await Task { @MainActor in
            try await windows.minimizeWindow(target: target)
        }.value
    }

    static func maximizeWindow(windows: any WindowManagementServiceProtocol, target: WindowTarget) async throws {
        try await Task { @MainActor in
            try await windows.maximizeWindow(target: target)
        }.value
    }

    static func moveWindow(
        windows: any WindowManagementServiceProtocol,
        target: WindowTarget,
        to origin: CGPoint
    ) async throws {
        try await Task { @MainActor in
            try await windows.moveWindow(target: target, to: origin)
        }.value
    }

    static func resizeWindow(
        windows: any WindowManagementServiceProtocol,
        target: WindowTarget,
        to size: CGSize
    ) async throws {
        try await Task { @MainActor in
            try await windows.resizeWindow(target: target, to: size)
        }.value
    }

    static func setWindowBounds(
        windows: any WindowManagementServiceProtocol,
        target: WindowTarget,
        bounds: CGRect
    ) async throws {
        try await Task { @MainActor in
            try await windows.setWindowBounds(target: target, bounds: bounds)
        }.value
    }

    static func focusWindow(windows: any WindowManagementServiceProtocol, target: WindowTarget) async throws {
        try await Task { @MainActor in
            try await windows.focusWindow(target: target)
        }.value
    }

    static func listWindows(
        windows: any WindowManagementServiceProtocol,
        target: WindowTarget
    ) async throws -> [ServiceWindowInfo] {
        try await Task { @MainActor in
            try await windows.listWindows(target: target)
        }.value
    }
}

enum MenuServiceBridge {
    static func listMenus(menu: any MenuServiceProtocol, appIdentifier: String) async throws -> MenuStructure {
        try await Task { @MainActor in
            try await menu.listMenus(for: appIdentifier)
        }.value
    }

    static func listFrontmostMenus(menu: any MenuServiceProtocol) async throws -> MenuStructure {
        try await Task { @MainActor in
            try await menu.listFrontmostMenus()
        }.value
    }

    static func listMenuExtras(menu: any MenuServiceProtocol) async throws -> [MenuExtraInfo] {
        try await Task { @MainActor in
            try await menu.listMenuExtras()
        }.value
    }

    static func clickMenuItem(menu: any MenuServiceProtocol, appIdentifier: String, itemPath: String) async throws {
        try await Task { @MainActor in
            try await menu.clickMenuItem(app: appIdentifier, itemPath: itemPath)
        }.value
    }

    static func clickMenuItemByName(
        menu: any MenuServiceProtocol,
        appIdentifier: String,
        itemName: String
    ) async throws {
        try await Task { @MainActor in
            try await menu.clickMenuItemByName(app: appIdentifier, itemName: itemName)
        }.value
    }

    static func clickMenuExtra(menu: any MenuServiceProtocol, title: String) async throws {
        try await Task { @MainActor in
            try await menu.clickMenuExtra(title: title)
        }.value
    }

    static func listMenuBarItems(menu: any MenuServiceProtocol, includeRaw: Bool = false) async throws
    -> [MenuBarItemInfo] {
        try await Task { @MainActor in
            try await menu.listMenuBarItems(includeRaw: includeRaw)
        }.value
    }

    static func clickMenuBarItem(named name: String, menu: any MenuServiceProtocol) async throws -> PeekabooCore
    .ClickResult {
        try await Task<PeekabooCore.ClickResult, any Error> { @MainActor in
            try await menu.clickMenuBarItem(named: name)
        }.value
    }

    static func clickMenuBarItem(at index: Int, menu: any MenuServiceProtocol) async throws -> PeekabooCore
    .ClickResult {
        try await Task<PeekabooCore.ClickResult, any Error> { @MainActor in
            try await menu.clickMenuBarItem(at: index)
        }.value
    }
}

enum DockServiceBridge {
    static func launchFromDock(dock: any DockServiceProtocol, appName: String) async throws {
        try await Task { @MainActor in
            try await dock.launchFromDock(appName: appName)
        }.value
    }

    static func findDockItem(dock: any DockServiceProtocol, name: String) async throws -> DockItem {
        try await Task { @MainActor in
            try await dock.findDockItem(name: name)
        }.value
    }

    static func rightClickDockItem(dock: any DockServiceProtocol, appName: String, menuItem: String?) async throws {
        try await Task { @MainActor in
            try await dock.rightClickDockItem(appName: appName, menuItem: menuItem)
        }.value
    }

    static func hideDock(dock: any DockServiceProtocol) async throws {
        try await Task { @MainActor in
            try await dock.hideDock()
        }.value
    }

    static func showDock(dock: any DockServiceProtocol) async throws {
        try await Task { @MainActor in
            try await dock.showDock()
        }.value
    }

    static func listDockItems(dock: any DockServiceProtocol, includeAll: Bool) async throws -> [DockItem] {
        try await Task { @MainActor in
            try await dock.listDockItems(includeAll: includeAll)
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
