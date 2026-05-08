import CoreGraphics
import Foundation
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooBridge
import PeekabooFoundation

@MainActor
public class RemoteUIAutomationService: DetectElementsRequestTimeoutAdjusting, TargetedHotkeyServiceProtocol {
    let client: PeekabooBridgeClient
    public let supportsTargetedHotkeys: Bool
    public let targetedHotkeyUnavailableReason: String?
    public let targetedHotkeyRequiresEventSynthesizingPermission: Bool

    public init(
        client: PeekabooBridgeClient,
        supportsTargetedHotkeys: Bool = false,
        targetedHotkeyUnavailableReason: String? = nil,
        targetedHotkeyRequiresEventSynthesizingPermission: Bool = false)
    {
        self.client = client
        self.supportsTargetedHotkeys = supportsTargetedHotkeys
        self.targetedHotkeyUnavailableReason = targetedHotkeyUnavailableReason
        self.targetedHotkeyRequiresEventSynthesizingPermission = targetedHotkeyRequiresEventSynthesizingPermission
    }

    public func detectElements(
        in imageData: Data,
        snapshotId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        try await self.detectElements(
            in: imageData,
            snapshotId: snapshotId,
            windowContext: windowContext,
            requestTimeoutSec: 30)
    }

    public func detectElements(
        in imageData: Data,
        snapshotId: String?,
        windowContext: WindowContext?,
        requestTimeoutSec: TimeInterval) async throws -> ElementDetectionResult
    {
        try await self.client.detectElements(
            in: imageData,
            snapshotId: snapshotId,
            windowContext: windowContext,
            requestTimeoutSec: requestTimeoutSec)
    }

    public func click(target: ClickTarget, clickType: ClickType, snapshotId: String?) async throws {
        try await self.client.click(target: target, clickType: clickType, snapshotId: snapshotId)
    }

    public func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        snapshotId: String?) async throws
    {
        try await self.client.type(
            text: text,
            target: target,
            clearExisting: clearExisting,
            typingDelay: typingDelay,
            snapshotId: snapshotId)
    }

    public func typeActions(
        _ actions: [TypeAction],
        cadence: TypingCadence,
        snapshotId: String?) async throws -> TypeResult
    {
        try await self.client.typeActions(actions, cadence: cadence, snapshotId: snapshotId)
    }

    public func scroll(_ request: ScrollRequest) async throws {
        try await self.client.scroll(request)
    }

    public func hotkey(keys: String, holdDuration: Int) async throws {
        try await self.client.hotkey(keys: keys, holdDuration: holdDuration)
    }

    public func hotkey(keys: String, holdDuration: Int, targetProcessIdentifier: pid_t) async throws {
        guard self.supportsTargetedHotkeys else {
            throw Self.targetedHotkeyUnavailableError(
                reason: self.targetedHotkeyUnavailableReason,
                requiresEventSynthesizingPermission: self.targetedHotkeyRequiresEventSynthesizingPermission)
        }

        do {
            try await self.client.hotkey(
                keys: keys,
                holdDuration: holdDuration,
                targetProcessIdentifier: targetProcessIdentifier)
        } catch let envelope as PeekabooBridgeErrorEnvelope {
            switch envelope.code {
            case .permissionDenied:
                throw Self.permissionDeniedError(for: envelope)
            case .invalidRequest:
                throw PeekabooError.invalidInput(envelope.message)
            case .operationNotSupported:
                throw PeekabooError.serviceUnavailable(envelope.message)
            default:
                throw envelope
            }
        }
    }

    private static func targetedHotkeyUnavailableError(
        reason: String?,
        requiresEventSynthesizingPermission: Bool) -> PeekabooError
    {
        if requiresEventSynthesizingPermission {
            return .permissionDeniedEventSynthesizing
        }

        return .serviceUnavailable(
            reason ?? "Remote bridge host does not support background hotkeys; use --no-remote or update the host")
    }

    private static func permissionDeniedError(for envelope: PeekabooBridgeErrorEnvelope) -> PeekabooError {
        switch envelope.permission {
        case .postEvent:
            .permissionDeniedEventSynthesizing
        case .accessibility:
            .permissionDeniedAccessibility
        case .screenRecording:
            .permissionDeniedScreenRecording
        case .appleScript, .none:
            .permissionDeniedEventSynthesizing
        }
    }

    public func swipe(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        try await self.client.swipe(from: from, to: to, duration: duration, steps: steps, profile: profile)
    }

    public func hasAccessibilityPermission() async -> Bool {
        do {
            let status = try await self.client.permissionsStatus()
            return status.accessibility
        } catch {
            return false
        }
    }

    public func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        snapshotId: String?) async throws -> WaitForElementResult
    {
        try await self.client.waitForElement(target: target, timeout: timeout, snapshotId: snapshotId)
    }

    public func drag(_ request: DragOperationRequest) async throws {
        try await self.client.drag(PeekabooBridgeDragRequest(request))
    }

    public func moveMouse(to: CGPoint, duration: Int, steps: Int, profile: MouseMovementProfile) async throws {
        try await self.client.moveMouse(to: to, duration: duration, steps: steps, profile: profile)
    }

    public func getFocusedElement() -> UIFocusInfo? {
        // Not yet implemented over XPC; fall back to nil to avoid blocking callers.
        nil
    }

    public func findElement(matching criteria: UIElementSearchCriteria, in appName: String?) async throws
        -> DetectedElement
    {
        // Currently unsupported over XPC; this path is rarely used by CLI.
        throw PeekabooError.operationError(message: "findElement is not available over XPC yet")
    }
}

@MainActor
public final class RemoteElementActionUIAutomationService: RemoteUIAutomationService,
ElementActionAutomationServiceProtocol {
    public func setValue(target: String, value: UIElementValue, snapshotId: String?) async throws
        -> ElementActionResult
    {
        try await self.client.setValue(target: target, value: value, snapshotId: snapshotId)
    }

    public func performAction(target: String, actionName: String, snapshotId: String?) async throws
        -> ElementActionResult
    {
        try await self.client.performAction(target: target, actionName: actionName, snapshotId: snapshotId)
    }
}
