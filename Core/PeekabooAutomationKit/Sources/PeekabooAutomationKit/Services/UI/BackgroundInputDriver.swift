@preconcurrency import AXorcist
import CoreGraphics
import Darwin
import PeekabooFoundation

/// Synthetic input that targets a process directly instead of the global HID tap.
///
/// This keeps the user's frontmost app and cursor alone. It is best-effort:
/// macOS delivers pid-routed CGEvents differently from hardware events, and
/// some apps ignore background mouse events unless they also expose an AX path.
enum BackgroundInputDriver {
    static func click(
        at point: CGPoint,
        button: MouseButton,
        count: Int,
        targetProcessIdentifier: pid_t) throws
    {
        guard CGPreflightPostEventAccess() else {
            throw PeekabooError.permissionDeniedEventSynthesizing
        }

        guard targetProcessIdentifier > 0, self.isProcessAlive(targetProcessIdentifier) else {
            throw PeekabooError.invalidInput("Target process identifier is not running: \(targetProcessIdentifier)")
        }

        let (downType, upType, cgButton) = Self.eventTypes(for: button)
        let source = CGEventSource(stateID: .hidSystemState)
        let clampedCount = max(1, min(3, count))

        for clickIndex in 1...clampedCount {
            guard
                let down = CGEvent(
                    mouseEventSource: source,
                    mouseType: downType,
                    mouseCursorPosition: point,
                    mouseButton: cgButton),
                let up = CGEvent(
                    mouseEventSource: source,
                    mouseType: upType,
                    mouseCursorPosition: point,
                    mouseButton: cgButton)
            else {
                throw PeekabooError.operationError(message: "Failed to create background mouse events")
            }

            down.setIntegerValueField(.mouseEventClickState, value: Int64(clickIndex))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(clickIndex))
            self.stampRoutingFields(on: down, at: point, targetProcessIdentifier: targetProcessIdentifier)
            self.stampRoutingFields(on: up, at: point, targetProcessIdentifier: targetProcessIdentifier)

            Self.post(down, to: targetProcessIdentifier)
            usleep(30000)
            Self.post(up, to: targetProcessIdentifier)

            if clickIndex < clampedCount {
                usleep(80000)
            }
        }
    }

    private static func post(_ event: CGEvent, to pid: pid_t) {
        if !SkyLightPerPidEventPost.post(event, to: pid) {
            event.postToPid(pid)
        }
    }

    private static func stampRoutingFields(
        on event: CGEvent,
        at point: CGPoint,
        targetProcessIdentifier: pid_t)
    {
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(targetProcessIdentifier))

        guard let windowID = self.windowID(containing: point, targetProcessIdentifier: targetProcessIdentifier) else {
            return
        }

        let value = Int64(windowID)
        event.setIntegerValueField(.windowID, value: value)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: value)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: value)
    }

    private static func windowID(containing point: CGPoint, targetProcessIdentifier: pid_t) -> CGWindowID? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        else {
            return nil
        }

        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == targetProcessIdentifier,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let windowNumber = window[kCGWindowNumber as String] as? CGWindowID,
                  let boundsValue = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsValue as CFDictionary),
                  bounds.contains(point)
            else {
                continue
            }

            return windowNumber
        }

        return nil
    }

    private static func eventTypes(for button: MouseButton) -> (CGEventType, CGEventType, CGMouseButton) {
        switch button {
        case .left:
            (.leftMouseDown, .leftMouseUp, .left)
        case .right:
            (.rightMouseDown, .rightMouseUp, .right)
        case .middle:
            (.otherMouseDown, .otherMouseUp, .center)
        }
    }

    private static func isProcessAlive(_ processIdentifier: pid_t) -> Bool {
        errno = 0
        if kill(processIdentifier, 0) == 0 {
            return true
        }
        return errno == EPERM
    }
}

private enum SkyLightPerPidEventPost {
    private typealias PostToPidFn = @convention(c) (pid_t, CGEvent) -> Void

    private static let postToPid: PostToPidFn? = {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY)
        else {
            return nil
        }
        guard let symbol = dlsym(handle, "SLEventPostToPid") else {
            return nil
        }
        return unsafeBitCast(symbol, to: PostToPidFn.self)
    }()

    @discardableResult
    static func post(_ event: CGEvent, to pid: pid_t) -> Bool {
        guard let postToPid else {
            return false
        }
        postToPid(pid, event)
        return true
    }
}
