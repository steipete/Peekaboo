import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

private struct SearchLimits {
    let maxDepth: Int
    let maxChildren: Int
    let timeBudget: TimeInterval

    static func from(policy: SearchPolicy) -> SearchLimits {
        switch policy {
        case .balanced:
            SearchLimits(maxDepth: 8, maxChildren: 200, timeBudget: 0.15)
        case .debug:
            SearchLimits(maxDepth: 32, maxChildren: 2000, timeBudget: 1.0)
        }
    }
}

public enum SearchPolicy {
    case balanced
    case debug
}

private struct AXSearchResult {
    let element: Element
    let frame: CGRect
    let label: String?
}

private struct AXSearchOutcome {
    let element: Element
    let frame: CGRect
    let label: String?
    let warnings: [String]
}

/**
 * Primary UI automation service orchestrating specialized automation components.
 *
 * Provides unified interface for UI interactions including element detection, clicking, typing,
 * scrolling, and gestures. Delegates to specialized services while managing snapshots and
 * providing visual feedback integration.
 *
 * ## Core Operations
 * - Element detection using AI-powered recognition
 * - Click, type, scroll, hotkey, and gesture operations
 * - Snapshot management for stateful automation workflows
 * - Visual feedback via PeekabooVisualizer integration
 *
 * ## Usage Example
 * ```swift
 * let automation = UIAutomationService()
 *
 * // Detect elements in screenshot
 * let elements = try await automation.detectElements(
 *     in: imageData,
 *     snapshotId: "snapshot_123",
 *     windowContext: windowContext
 * )
 *
 * // Perform automation
 * try await automation.click(target: .elementId("B1"), clickType: .single, snapshotId: "snapshot_123")
 * try await automation.type(text: "Hello World", target: "T1", clearExisting: true, snapshotId: "snapshot_123")
 * ```
 *
 * - Important: Requires Screen Recording and Accessibility permissions
 * - Note: All operations run on MainActor, performance varies 10-800ms by operation
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
public final class UIAutomationService: TargetedHotkeyServiceProtocol {
    let logger = Logger(subsystem: "boo.peekaboo.core", category: "UIAutomationService")
    let snapshotManager: any SnapshotManagerProtocol

    // Specialized services
    let elementDetectionService: ElementDetectionService
    let clickService: ClickService
    let typeService: TypeService
    let scrollService: ScrollService
    let hotkeyService: HotkeyService
    let gestureService: GestureService
    let screenCaptureService: ScreenCaptureService

    let feedbackClient: any AutomationFeedbackClient

    // Search constraints to prevent unbounded AX traversals
    private var searchLimits: SearchLimits
    public private(set) var searchPolicy: SearchPolicy

    /**
     * Initialize the UI automation service with optional dependency injection.
     *
     * Creates a new automation service instance with all specialized services properly configured.
     * The service automatically detects its runtime environment and configures visualizer integration
     * appropriately (disabled when running inside the Mac app, enabled for CLI tools).
     *
     * - Parameters:
     *   - snapshotManager: Snapshot manager for state tracking (creates default if nil)
     *   - loggingService: Logging service for debug output (creates default if nil)
     *
     * ## Service Initialization
     * The constructor initializes these specialized services:
     * - `ElementDetectionService` with AX traversal collaborators
     * - `ClickService` for precise mouse interactions
     * - `TypeService` for intelligent text input (note: clickService parameter is nil to avoid circular dependency)
     * - `ScrollService` for smooth scrolling operations
     * - `HotkeyService` for system-level keyboard shortcuts
     * - `GestureService` for complex mouse gestures and drag operations
     * - `ScreenCaptureService` with logging integration
     *
     * ## Visualizer Integration
     * Automatically connects to PeekabooVisualizer for real-time feedback unless running
     * inside the Mac app (bundle ID: "boo.peekaboo.mac"). This prevents the Mac app from
     * trying to connect to itself as a visualizer client.
     *
     * ## Example
     * ```swift
     * // Default initialization
     * let automation = UIAutomationService()
     *
     * // With custom snapshot manager
     * let customSnapshot = SnapshotManager()
     * let automation = UIAutomationService(snapshotManager: customSnapshot)
     * ```
     *
     * - Important: All services are initialized on the main thread due to UI automation requirements
     * - Note: The visualizer connection is established asynchronously and failures are logged but not thrown
     */
    public init(
        snapshotManager: (any SnapshotManagerProtocol)? = nil,
        loggingService: (any LoggingServiceProtocol)? = nil,
        searchPolicy: SearchPolicy = .balanced,
        feedbackClient: any AutomationFeedbackClient = NoopAutomationFeedbackClient())
    {
        let manager = snapshotManager ?? SnapshotManager()
        self.snapshotManager = manager

        let logger = loggingService ?? LoggingService()

        self.searchPolicy = searchPolicy
        self.searchLimits = SearchLimits.from(policy: searchPolicy)
        self.feedbackClient = feedbackClient

        // Initialize specialized services
        self.elementDetectionService = ElementDetectionService(snapshotManager: manager)
        self.clickService = ClickService(snapshotManager: manager)
        self.typeService = TypeService(snapshotManager: manager, clickService: nil)
        self.scrollService = ScrollService(snapshotManager: manager, clickService: nil)
        self.hotkeyService = HotkeyService()
        self.gestureService = GestureService()
        let baseCaptureDeps = ScreenCaptureService.Dependencies.live()
        let captureDeps = ScreenCaptureService.Dependencies(
            feedbackClient: feedbackClient,
            permissionEvaluator: baseCaptureDeps.permissionEvaluator,
            fallbackRunner: baseCaptureDeps.fallbackRunner,
            applicationResolver: baseCaptureDeps.applicationResolver,
            makeFrameSource: baseCaptureDeps.makeFrameSource,
            makeModernOperator: baseCaptureDeps.makeModernOperator,
            makeLegacyOperator: baseCaptureDeps.makeLegacyOperator)
        self.screenCaptureService = ScreenCaptureService(loggingService: logger, dependencies: captureDeps)

        // Connect to visual feedback if available.
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.feedbackClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }
}

extension UIAutomationService {
    // MARK: - Accessibility and Focus

    public func hasAccessibilityPermission() async -> Bool {
        self.logger.debug("Checking accessibility permission")
        return AXPermissionHelpers.hasAccessibilityPermissions()
    }

    @MainActor
    public func getFocusedElement() -> UIFocusInfo? {
        self.logger.debug("Getting focused element")

        let systemWide = Element.systemWide()

        guard let focusedElement = systemWide.focusedUIElement() else {
            self.logger.debug("No focused element found")
            return nil
        }

        let role = focusedElement.role() ?? "Unknown"
        let title = focusedElement.title()
        let value = focusedElement.stringValue()
        let frame = focusedElement.frame() ?? .zero

        let elementPid = focusedElement.pid()
        let resolvedPid: pid_t? = {
            if let elementPid, elementPid > 0 {
                return elementPid
            }

            let frontmostPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if let frontmostPid, frontmostPid > 0 {
                return frontmostPid
            }

            return nil
        }()

        let app = resolvedPid.flatMap { AXApp(pid: $0) }
        let runningApp = resolvedPid.flatMap { NSRunningApplication(processIdentifier: $0) }

        return UIFocusInfo(
            role: role,
            title: title,
            value: value,
            frame: frame,
            applicationName: app?.localizedName ?? runningApp?.localizedName ?? "Unknown",
            bundleIdentifier: app?.bundleIdentifier ?? runningApp?.bundleIdentifier ?? "Unknown",
            processId: resolvedPid.map(Int.init) ?? 0)
    }

    // MARK: - Wait for Element

    public func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        snapshotId: String?) async throws -> WaitForElementResult
    {
        self.logger.debug("Waiting for element - target: \(String(describing: target)), timeout: \(timeout)s")

        var accumulatedWarnings: [String] = []

        if case .coordinates = target {
            return WaitForElementResult(found: true, element: nil, waitTime: 0, warnings: accumulatedWarnings)
        }

        let startTime = Date()
        let deadline = startTime.addingTimeInterval(timeout)
        let retryInterval: UInt64 = 100_000_000 // 100ms

        while Date() < deadline {
            let result = await self.locateElementForWait(target: target, snapshotId: snapshotId)
            accumulatedWarnings.append(contentsOf: result.warnings)
            if let element = result.element {
                let waitTime = Date().timeIntervalSince(startTime)
                self.logger.debug("Found element for target \(String(describing: target)) after \(waitTime)s")
                return WaitForElementResult(
                    found: true,
                    element: element,
                    waitTime: waitTime,
                    warnings: accumulatedWarnings)
            }

            try await Task.sleep(nanoseconds: retryInterval)
        }

        self.logger.debug("Element not found after \(timeout)s timeout")
        return WaitForElementResult(found: false, element: nil, waitTime: timeout, warnings: accumulatedWarnings)
    }

    public func findElement(
        matching criteria: UIElementSearchCriteria,
        in appName: String?) async throws -> DetectedElement
    {
        self.logger.debug("Finding element matching criteria in app: \(appName ?? "any")")

        let captureResult: CaptureResult
        if let appName {
            let appService = ApplicationService()
            _ = try await appService.findApplication(identifier: appName)

            captureResult = try await self.screenCaptureService.captureWindow(
                appIdentifier: appName,
                windowIndex: nil)
        } else {
            captureResult = try await self.screenCaptureService.captureScreen(displayIndex: nil)
        }

        let detectionResult = try await detectElements(
            in: captureResult.imageData,
            snapshotId: nil,
            windowContext: nil)

        let allElements = detectionResult.elements.all

        for element in allElements {
            switch criteria {
            case let .label(searchLabel):
                let searchLower = searchLabel.lowercased()
                if let label = element.label?.lowercased(), label.contains(searchLower) {
                    return element
                }
                if let value = element.value?.lowercased(), value.contains(searchLower) {
                    return element
                }

            case let .identifier(searchId):
                if element.id == searchId {
                    return element
                }

            case let .type(searchType):
                if element.type.rawValue.lowercased() == searchType.lowercased() {
                    return element
                }
            }
        }

        let description = switch criteria {
        case let .label(label):
            "with label '\(label)'"
        case let .identifier(id):
            "with ID '\(id)'"
        case let .type(type):
            "of type '\(type)'"
        }

        throw PeekabooError.elementNotFound("element \(description) in \(appName ?? "screen")")
    }

    // MARK: - Private Helpers

    private func locateElementForWait(
        target: ClickTarget,
        snapshotId: String?) async -> (element: DetectedElement?, warnings: [String])
    {
        switch target {
        case let .elementId(id):
            guard let snapshotId,
                  let detectionResult = try? await snapshotManager.getDetectionResult(snapshotId: snapshotId)
            else {
                return (nil, [])
            }
            return (detectionResult.elements.findById(id), [])

        case let .query(query):
            if let element = await self.findElementInSession(query: query, snapshotId: snapshotId) {
                return (element, [])
            }
            guard let info = self.findElementByAccessibility(matching: query) else {
                return (nil, [])
            }
            return (
                DetectedElement(
                    id: "wait_found",
                    type: .other,
                    label: info.label ?? query,
                    value: nil,
                    bounds: info.frame,
                    isEnabled: true),
                info.warnings)

        case .coordinates:
            return (nil, [])
        }
    }

    private func findElementInSession(query: String, snapshotId: String?) async -> DetectedElement? {
        guard let snapshotId,
              let detectionResult = try? await snapshotManager.getDetectionResult(snapshotId: snapshotId)
        else {
            return nil
        }

        return ClickService.resolveTargetElement(query: query, in: detectionResult)
    }

    private func findElementByAccessibility(matching query: String) -> AXSearchOutcome? {
        guard let app = MouseLocationUtilities.findApplicationAtMouseLocation() else {
            return nil
        }

        let appElement = AXApp(app).element

        let deadline = Date().addingTimeInterval(self.searchLimits.timeBudget)
        let searchContext = SearchContext(
            query: query.lowercased(),
            limits: self.searchLimits,
            deadline: deadline)
        let (result, warnings) = self.searchElementRecursively(
            in: appElement,
            depth: 0,
            context: searchContext,
            warnings: [])

        guard let result else { return nil }
        return AXSearchOutcome(element: result.element, frame: result.frame, label: result.label, warnings: warnings)
    }

    private struct SearchContext {
        let query: String
        let limits: SearchLimits
        let deadline: Date
    }

    private func searchElementRecursively(
        in element: Element,
        depth: Int,
        context: SearchContext,
        warnings: [String]) -> (result: AXSearchResult?, warnings: [String])
    {
        var currentWarnings = warnings

        let limits = context.limits
        if depth > limits.maxDepth {
            self.logger.debug("AX search aborted: maxDepth reached at depth \(depth)")
            currentWarnings.append("depth_limit")
            return (nil, currentWarnings)
        }

        if Date() > context.deadline {
            self.logger.debug("AX search aborted: time budget exceeded")
            currentWarnings.append("time_budget_exceeded")
            return (nil, currentWarnings)
        }

        let title = element.title()?.lowercased() ?? ""
        let label = element.label()?.lowercased() ?? ""
        let value = element.stringValue()?.lowercased() ?? ""
        let roleDescription = element.roleDescription()?.lowercased() ?? ""

        if title.contains(context.query) || label.contains(context.query) ||
            value.contains(context.query) || roleDescription.contains(context.query)
        {
            if let frame = element.frame() {
                let displayLabel = element.title() ?? element.label() ?? element.roleDescription()
                return (AXSearchResult(element: element, frame: frame, label: displayLabel), currentWarnings)
            }
        }

        if let children = element.children() {
            let limitedChildren = children.prefix(limits.maxChildren)
            for child in limitedChildren {
                let (found, childWarnings) = self.searchElementRecursively(
                    in: child,
                    depth: depth + 1,
                    context: context,
                    warnings: currentWarnings)
                if let found {
                    return (found, childWarnings)
                }
            }

            if children.count > limits.maxChildren {
                self.logger.debug("AX search truncated children: \(children.count) > \(limits.maxChildren)")
                currentWarnings.append("child_limit")
            }
        }

        return (nil, currentWarnings)
    }
}
