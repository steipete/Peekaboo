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
public final class UIAutomationService: UIAutomationServiceProtocol {
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
     * - `ElementDetectionService` with snapshot management integration
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
    // MARK: - Element Detection

    /**
     * Detect and analyze UI elements in a captured screen image using AI-powered recognition.
     *
     * This method uses advanced computer vision and AI models to identify interactive UI elements
     * in screenshots. Elements are classified by type (buttons, text fields, etc.) and assigned
     * unique identifiers for subsequent automation operations.
     *
     * - Parameters:
     *   - imageData: PNG or JPEG image data containing the screen capture
     *   - snapshotId: Optional snapshot identifier for element caching and state management
     *   - windowContext: Optional context about the captured window for improved accuracy
     * - Returns: `ElementDetectionResult` containing detected elements and metadata
     * - Throws: `PeekabooError` if detection fails or image data is invalid
     *
     * ## Detection Process
     * 1. **Image Analysis**: AI model analyzes the screenshot for UI patterns
     * 2. **Element Classification**: Elements are categorized (button, textField, image, etc.)
     * 3. **Coordinate Mapping**: Screen coordinates are calculated for each element
     * 4. **Accessibility Correlation**: Elements are matched with accessibility tree data
     * 5. **Session Caching**: Results are stored for quick access in subsequent operations
     *
     * ## Element Types
     * Detected elements include:
     * - `button`: Clickable buttons and controls
     * - `textField`: Text input fields and text areas
     * - `image`: Images and icons
     * - `staticText`: Labels and static text content
     * - `other`: Other interactive elements
     *
     * ## Performance
     * - **Typical Duration**: 200-800ms depending on screen complexity
     * - **Caching**: Results are cached per snapshot to avoid re-detection
     * - **Batch Processing**: Multiple elements detected in single pass
     *
     * ## Example
     * ```swift
     * let captureResult = try await screenCapture.captureScreen()
     * let windowContext = WindowContext(
     *     applicationName: "Safari",
     *     windowTitle: "Apple",
     *     windowBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
     * )
     *
     * let elements = try await automation.detectElements(
     *     in: captureResult.imageData,
     *     snapshotId: "snapshot_123",
     *     windowContext: windowContext
     * )
     *
     * print("Detected \(elements.elements.all.count) elements")
     * for element in elements.elements.buttons {
     *     print("Button: \(element.label ?? "Unlabeled") at \(element.bounds)")
     * }
     * ```
     *
     * - Important: Requires Screen Recording permission for screen capture
     * - Note: Detection accuracy improves with window context information
     */
    public func detectElements(
        in imageData: Data,
        snapshotId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        self.logger.debug("Delegating element detection to ElementDetectionService")
        return try await self.elementDetectionService.detectElements(
            in: imageData,
            snapshotId: snapshotId,
            windowContext: windowContext)
    }

    // MARK: - Click Operations

    /**
     * Perform precise click operations on UI elements or screen coordinates.
     *
     * This method handles all types of mouse click interactions with intelligent targeting,
     * accessibility API integration, and visual feedback. It supports both element-based
     * and coordinate-based clicking with multiple click types.
     *
     * - Parameters:
     *   - target: The click target (element ID, query, or coordinates)
     *   - clickType: Type of click to perform (single, double, right-click, etc.)
     *   - snapshotId: Optional snapshot ID for element resolution and state tracking
     * - Throws: `PeekabooError` if the target cannot be found or click fails
     *
     * ## Click Targeting
     * Three targeting modes are supported:
     * - **Element ID**: Click on a specific detected element (e.g., "B1", "T3")
     * - **Query**: Find element by text content or accessibility label
     * - **Coordinates**: Click at exact screen coordinates
     *
     * ## Click Types
     * - `.single`: Standard left click
     * - `.double`: Double-click for opening/selecting
     * - `.right`: Right-click for context menus
     * - `.middle`: Middle-click (wheel button)
     *
     * ## Visual Feedback
     * When visualizer is connected, shows:
     * - Ripple animation at click location
     * - Click type indicator (single, double, right)
     * - Targeting crosshairs for precision feedback
     *
     * ## Performance
     * - **Element Resolution**: 10-50ms for cached elements
     * - **Accessibility Lookup**: 50-200ms for query-based targeting
     * - **Click Execution**: 5-20ms for coordinate-based clicks
     *
     * ## Example
     * ```swift
     * // Click on detected element
     * try await automation.click(
     *     target: .elementId("B1"),
     *     clickType: .single,
     *     snapshotId: "snapshot_123"
     * )
     *
     * // Click by searching for text
     * try await automation.click(
     *     target: .query("Submit"),
     *     clickType: .single,
     *     snapshotId: "snapshot_123"
     * )
     *
     * // Click at specific coordinates
     * try await automation.click(
     *     target: .coordinates(CGPoint(x: 100, y: 200)),
     *     clickType: .right,
     *     snapshotId: nil
     * )
     * ```
     *
     * - Important: Requires Accessibility permission for element-based clicking
     * - Note: Visual feedback is automatically shown if visualizer is connected
     */
    public func click(target: ClickTarget, clickType: ClickType, snapshotId: String?) async throws {
        self.logger.debug("Delegating click to ClickService")
        try await self.clickService.click(target: target, clickType: clickType, snapshotId: snapshotId)

        // Show visual feedback if available
        if let clickPoint = try await getClickPoint(for: target, snapshotId: snapshotId) {
            _ = await self.feedbackClient.showClickFeedback(at: clickPoint, type: clickType)
        }
    }

    private func getClickPoint(for target: ClickTarget, snapshotId: String?) async throws -> CGPoint? {
        switch target {
        case let .coordinates(point):
            return point
        case let .elementId(id):
            if let snapshotId,
               let result = try? await snapshotManager.getDetectionResult(snapshotId: snapshotId),
               let element = result.elements.findById(id)
            {
                return CGPoint(x: element.bounds.midX, y: element.bounds.midY)
            }
        case .query:
            // For queries, we don't have easy access to the clicked element's position
            // The click service would need to expose this information
            return nil
        }
        return nil
    }

    // MARK: - Typing Operations

    /**
     * Perform intelligent text input with focus management and visual feedback.
     *
     * This method handles text input operations with automatic focus management, existing
     * content clearing, and configurable typing speeds. It supports both targeted typing
     * (to specific elements) and global typing (to currently focused element).
     *
     * - Parameters:
     *   - text: The text to type
     *   - target: Optional element ID to type into (types to focused element if nil)
     *   - clearExisting: Whether to clear existing text before typing
     *   - typingDelay: Delay between keystrokes in milliseconds (for realistic typing)
     *   - snapshotId: Optional snapshot ID for element resolution
     * - Throws: `PeekabooError` if target element cannot be found or typing fails
     *
     * ## Focus Management
     * - **Targeted Typing**: Automatically focuses the specified element before typing
     * - **Global Typing**: Types into whatever element currently has focus
     * - **Focus Validation**: Ensures element can accept text input before proceeding
     *
     * ## Text Handling
     * - **Unicode Support**: Full Unicode character support including emoji
     * - **Special Characters**: Handles newlines, tabs, and special key combinations
     * - **Content Clearing**: Optional clearing of existing content via Cmd+A, Delete
     * - **Typing Simulation**: Realistic typing with configurable delays between characters
     *
     * ## Visual Feedback
     * When visualizer is connected, displays:
     * - Character-by-character typing indicators
     * - Typing speed visualization
     * - Target element highlighting
     * - Focus transition animations
     *
     * ## Performance
     * - **Focus Resolution**: 20-100ms for element focusing
     * - **Character Input**: Configurable delay (0-1000ms) per character
     * - **Content Clearing**: 50-150ms for Cmd+A, Delete sequence
     *
     * ## Example
     * ```swift
     * // Type into specific element with clearing
     * try await automation.type(
     *     text: "Hello World!",
     *     target: "T1",
     *     clearExisting: true,
     *     typingDelay: 50,
     *     snapshotId: "snapshot_123"
     * )
     *
     * // Type into currently focused element
     * try await automation.type(
     *     text: "Quick text",
     *     target: nil,
     *     clearExisting: false,
     *     typingDelay: 0,
     *     snapshotId: nil
     * )
     *
     * // Type with realistic human-like speed
     * try await automation.type(
     *     text: "Realistic typing simulation",
     *     target: "searchField",
     *     clearExisting: true,
     *     typingDelay: 100,
     *     snapshotId: "snapshot_123"
     * )
     * ```
     *
     * - Important: Requires Accessibility permission for element-based typing
     * - Note: Typing delay of 0 results in instant text insertion
     */
    public func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        snapshotId: String?) async throws
    {
        self.logger.debug("Delegating type to TypeService")
        try await self.typeService.type(
            text: text,
            target: target,
            clearExisting: clearExisting,
            typingDelay: typingDelay,
            snapshotId: snapshotId)

        // Show visual feedback if available
        await self.visualizeTyping(keys: Array(text).map { String($0) }, cadence: .fixed(milliseconds: typingDelay))
    }

    public func typeActions(
        _ actions: [TypeAction],
        cadence: TypingCadence,
        snapshotId: String?) async throws -> TypeResult
    {
        self.logger.debug("Delegating typeActions to TypeService")
        let result = try await self.typeService.typeActions(actions, cadence: cadence, snapshotId: snapshotId)
        await self.visualizeTypeActions(actions, cadence: cadence)
        return result
    }

    // MARK: - Typing Visualization Helpers

    func visualizeTypeActions(_ actions: [TypeAction], cadence: TypingCadence) async {
        let keys = self.keySequence(from: actions)
        await self.visualizeTyping(keys: keys, cadence: cadence)
    }

    func visualizeTyping(keys: [String], cadence: TypingCadence) async {
        guard !keys.isEmpty else { return }
        _ = await self.feedbackClient.showTypingFeedback(keys: keys, duration: 2.0, cadence: cadence)
    }

    private func keySequence(from actions: [TypeAction]) -> [String] {
        var sequence: [String] = []

        for action in actions {
            switch action {
            case let .text(text):
                sequence.append(contentsOf: text.map { String($0) })
            case let .key(key):
                sequence.append("{\(key.rawValue)}")
            case .clear:
                sequence.append(contentsOf: ["{cmd+a}", "{delete}"])
            }
        }

        return sequence
    }

    // MARK: - Scroll Operations

    /**
     * Perform smooth scrolling operations with visual feedback.
     *
     * - Parameter request: Scroll configuration including direction, amount, target, style, and snapshot context.
     * - Throws: `PeekabooError` if target element cannot be found.
     *
     * ## Example
     * ```swift
     * let request = ScrollRequest(direction: .down, amount: 5, smooth: true, delay: 10)
     * try await automation.scroll(request)
     * ```
     */
    public func scroll(_ request: ScrollRequest) async throws {
        self.logger.debug("Delegating scroll to ScrollService")
        try await self.scrollService.scroll(request)

        // Show visual feedback if available
        // Get current mouse location for scroll indicator
        let mouseLocation = NSEvent.mouseLocation
        _ = await self.feedbackClient.showScrollFeedback(
            at: mouseLocation,
            direction: request.direction,
            amount: request.amount)
    }

    // MARK: - Hotkey Operations

    /**
     * Execute keyboard shortcuts and key combinations.
     *
     * - Parameters:
     *   - keys: Comma-separated key combination (e.g., "cmd,c" for copy, "cmd,shift,t" for new tab)
     *   - holdDuration: Duration to hold keys in milliseconds (50-200ms typical)
     * - Throws: `PeekabooError` if invalid key combination or system hotkey execution fails
     *
     * ## Supported Keys
     * - Modifier keys: cmd, shift, alt, ctrl, fn
     * - Letters: a-z (case insensitive)
     * - Numbers: 0-9
     * - Special: space, return, tab, escape, delete
     * - Arrows: arrow_up, arrow_down, arrow_left, arrow_right
     * - Function: f1-f12
     *
     * ## Examples
     * ```swift
     * // Copy selection
     * try await automation.hotkey(keys: "cmd,c", holdDuration: 100)
     *
     * // Open new tab
     * try await automation.hotkey(keys: "cmd,t", holdDuration: 50)
     *
     * // Three-key combination
     * try await automation.hotkey(keys: "cmd,shift,z", holdDuration: 100)
     * ```
     */
    public func hotkey(keys: String, holdDuration: Int) async throws {
        self.logger.debug("Delegating hotkey to HotkeyService")
        try await self.hotkeyService.hotkey(keys: keys, holdDuration: holdDuration)

        // Show visual feedback if available
        let keyArray = keys.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        _ = await self.feedbackClient.showHotkeyDisplay(keys: keyArray, duration: 1.0)
    }

    // MARK: - Gesture Operations

    public func swipe(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        self.logger.debug("Delegating swipe to GestureService")
        try await self.gestureService.swipe(
            from: from,
            to: to,
            duration: duration,
            steps: steps,
            profile: profile)

        // Show visual feedback if available
        _ = await self.feedbackClient.showSwipeGesture(from: from, to: to, duration: TimeInterval(duration) / 1000.0)
    }

    // swiftlint:disable:next function_parameter_count
    public func drag(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        modifiers: String?,
        profile: MouseMovementProfile) async throws
    {
        self.logger.debug("Delegating drag to GestureService")
        try await self.gestureService.drag(
            from: from,
            to: to,
            duration: duration,
            steps: steps,
            modifiers: modifiers,
            profile: profile)
    }

    public func moveMouse(
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        self.logger.debug("Delegating moveMouse to GestureService")

        // Get current mouse position for the animation start point
        let fromPoint = NSEvent.mouseLocation

        try await self.gestureService.moveMouse(to: to, duration: duration, steps: steps, profile: profile)

        // Show visual feedback if available
        _ = await self.feedbackClient.showMouseMovement(
            from: fromPoint,
            to: to,
            duration: TimeInterval(duration) / 1000.0)
    }

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

        let queryLower = query.lowercased()
        return detectionResult.elements.all.first { element in
            let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                element.value?.lowercased().contains(queryLower) ?? false
            return matches && element.isEnabled
        }
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
