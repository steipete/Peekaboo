import AppKit
import ApplicationServices
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log

/**
 * Primary UI automation service orchestrating specialized automation components.
 *
 * Provides unified interface for UI interactions including element detection, clicking, typing,
 * scrolling, and gestures. Delegates to specialized services while managing sessions and
 * providing visual feedback integration.
 *
 * ## Core Operations
 * - Element detection using AI-powered recognition
 * - Click, type, scroll, hotkey, and gesture operations
 * - Session management for stateful automation workflows
 * - Visual feedback via PeekabooVisualizer integration
 *
 * ## Usage Example
 * ```swift
 * let automation = UIAutomationService()
 *
 * // Detect elements in screenshot
 * let elements = try await automation.detectElements(
 *     in: imageData,
 *     sessionId: "session_123",
 *     windowContext: windowContext
 * )
 *
 * // Perform automation
 * try await automation.click(target: .elementId("B1"), clickType: .single, sessionId: "session_123")
 * try await automation.type(text: "Hello World", target: "T1", clearExisting: true, sessionId: "session_123")
 * ```
 *
 * - Important: Requires Screen Recording and Accessibility permissions
 * - Note: All operations run on MainActor, performance varies 10-800ms by operation
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
public final class UIAutomationService: UIAutomationServiceProtocol {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "UIAutomationService")
    private let sessionManager: SessionManagerProtocol

    // Specialized services
    private let elementDetectionService: ElementDetectionService
    private let clickService: ClickService
    private let typeService: TypeService
    private let scrollService: ScrollService
    private let hotkeyService: HotkeyService
    private let gestureService: GestureService
    private let screenCaptureService: ScreenCaptureService

    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared

    /**
     * Initialize the UI automation service with optional dependency injection.
     *
     * Creates a new automation service instance with all specialized services properly configured.
     * The service automatically detects its runtime environment and configures visualizer integration
     * appropriately (disabled when running inside the Mac app, enabled for CLI tools).
     *
     * - Parameters:
     *   - sessionManager: Session manager for state tracking (creates default if nil)
     *   - loggingService: Logging service for debug output (creates default if nil)
     *
     * ## Service Initialization
     * The constructor initializes these specialized services:
     * - `ElementDetectionService` with session management integration
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
     * // With custom session manager
     * let customSession = SessionManager()
     * let automation = UIAutomationService(sessionManager: customSession)
     * ```
     *
     * - Important: All services are initialized on the main thread due to UI automation requirements
     * - Note: The visualizer connection is established asynchronously and failures are logged but not thrown
     */
    public init(sessionManager: SessionManagerProtocol? = nil, loggingService: LoggingServiceProtocol? = nil) {
        let manager = sessionManager ?? SessionManager()
        self.sessionManager = manager

        let logger = loggingService ?? LoggingService()

        // Initialize specialized services
        self.elementDetectionService = ElementDetectionService(sessionManager: manager)
        self.clickService = ClickService(sessionManager: manager)
        self.typeService = TypeService(sessionManager: manager, clickService: nil)
        self.scrollService = ScrollService(sessionManager: manager, clickService: nil)
        self.hotkeyService = HotkeyService()
        self.gestureService = GestureService()
        self.screenCaptureService = ScreenCaptureService(loggingService: logger)

        // Connect to visualizer if available
        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier == "boo.peekaboo.mac"
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }

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
     *   - sessionId: Optional session identifier for element caching and state management
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
     * - **Caching**: Results are cached per session to avoid re-detection
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
     *     sessionId: "session_123",
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
        sessionId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        self.logger.debug("Delegating element detection to ElementDetectionService")
        return try await self.elementDetectionService.detectElements(
            in: imageData,
            sessionId: sessionId,
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
     *   - sessionId: Optional session ID for element resolution and state tracking
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
     *     sessionId: "session_123"
     * )
     *
     * // Click by searching for text
     * try await automation.click(
     *     target: .query("Submit"),
     *     clickType: .single,
     *     sessionId: "session_123"
     * )
     *
     * // Click at specific coordinates
     * try await automation.click(
     *     target: .coordinates(CGPoint(x: 100, y: 200)),
     *     clickType: .right,
     *     sessionId: nil
     * )
     * ```
     *
     * - Important: Requires Accessibility permission for element-based clicking
     * - Note: Visual feedback is automatically shown if visualizer is connected
     */
    public func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        self.logger.debug("Delegating click to ClickService")
        try await self.clickService.click(target: target, clickType: clickType, sessionId: sessionId)

        // Show visual feedback if available
        if let clickPoint = try await getClickPoint(for: target, sessionId: sessionId) {
            _ = await self.visualizerClient.showClickFeedback(at: clickPoint, type: clickType)
        }
    }

    private func getClickPoint(for target: ClickTarget, sessionId: String?) async throws -> CGPoint? {
        switch target {
        case let .coordinates(point):
            return point
        case let .elementId(id):
            if let sessionId,
               let result = try? await sessionManager.getDetectionResult(sessionId: sessionId),
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
     *   - sessionId: Optional session ID for element resolution
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
     *     sessionId: "session_123"
     * )
     *
     * // Type into currently focused element
     * try await automation.type(
     *     text: "Quick text",
     *     target: nil,
     *     clearExisting: false,
     *     typingDelay: 0,
     *     sessionId: nil
     * )
     *
     * // Type with realistic human-like speed
     * try await automation.type(
     *     text: "Realistic typing simulation",
     *     target: "searchField",
     *     clearExisting: true,
     *     typingDelay: 100,
     *     sessionId: "session_123"
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
        sessionId: String?) async throws
    {
        self.logger.debug("Delegating type to TypeService")
        try await self.typeService.type(
            text: text,
            target: target,
            clearExisting: clearExisting,
            typingDelay: typingDelay,
            sessionId: sessionId)

        // Show visual feedback if available
        let keys = Array(text).map { String($0) }
        _ = await self.visualizerClient.showTypingFeedback(keys: keys, duration: 2.0)
    }

    public func typeActions(_ actions: [TypeAction], typingDelay: Int, sessionId: String?) async throws -> TypeResult {
        self.logger.debug("Delegating typeActions to TypeService")
        return try await self.typeService.typeActions(actions, typingDelay: typingDelay, sessionId: sessionId)
    }

    // MARK: - Scroll Operations

    /**
     * Perform smooth scrolling operations with visual feedback.
     *
     * - Parameters:
     *   - direction: Scroll direction (.up, .down, .left, .right)
     *   - amount: Number of scroll units/lines to scroll (1-100 typical range)
     *   - target: Optional element ID to scroll within (scrolls at mouse position if nil)
     *   - smooth: Whether to use smooth scrolling with smaller increments
     *   - delay: Delay in milliseconds between scroll increments (1-50ms typical)
     *   - sessionId: Session ID for element resolution if target is specified
     * - Throws: `PeekabooError` if target element cannot be found
     *
     * ## Example
     * ```swift
     * // Scroll down 5 units smoothly
     * try await automation.scroll(
     *     direction: .down,
     *     amount: 5,
     *     target: nil,
     *     smooth: true,
     *     delay: 10,
     *     sessionId: nil
     * )
     * ```
     */
    public func scroll(
        direction: ScrollDirection,
        amount: Int,
        target: String?,
        smooth: Bool,
        delay: Int,
        sessionId: String?) async throws
    {
        self.logger.debug("Delegating scroll to ScrollService")
        try await self.scrollService.scroll(
            direction: direction,
            amount: amount,
            target: target,
            smooth: smooth,
            delay: delay,
            sessionId: sessionId)

        // Show visual feedback if available
        // Get current mouse location for scroll indicator
        let mouseLocation = NSEvent.mouseLocation
        _ = await self.visualizerClient.showScrollFeedback(at: mouseLocation, direction: direction, amount: amount)
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
        _ = await self.visualizerClient.showHotkeyDisplay(keys: keyArray, duration: 1.0)
    }

    // MARK: - Gesture Operations

    public func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        self.logger.debug("Delegating swipe to GestureService")
        try await self.gestureService.swipe(from: from, to: to, duration: duration, steps: steps)

        // Show visual feedback if available
        _ = await self.visualizerClient.showSwipeGesture(from: from, to: to, duration: TimeInterval(duration) / 1000.0)
    }

    public func drag(from: CGPoint, to: CGPoint, duration: Int, steps: Int, modifiers: String?) async throws {
        self.logger.debug("Delegating drag to GestureService")
        try await self.gestureService.drag(
            from: from,
            to: to,
            duration: duration,
            steps: steps,
            modifiers: modifiers)
    }

    public func moveMouse(to: CGPoint, duration: Int, steps: Int) async throws {
        self.logger.debug("Delegating moveMouse to GestureService")

        // Get current mouse position for the animation start point
        let fromPoint = NSEvent.mouseLocation

        try await self.gestureService.moveMouse(to: to, duration: duration, steps: steps)

        // Show visual feedback if available
        _ = await self.visualizerClient.showMouseMovement(
            from: fromPoint,
            to: to,
            duration: TimeInterval(duration) / 1000.0)
    }

    // MARK: - Accessibility and Focus

    public func hasAccessibilityPermission() async -> Bool {
        self.logger.debug("Checking accessibility permission")
        return AXIsProcessTrusted()
    }

    /**
     * Retrieve information about the currently focused UI element system-wide.
     *
     * This method queries the macOS accessibility system to find the element that currently
     * has keyboard focus anywhere on the system. Returns detailed information about the
     * focused element including its properties, application context, and screen coordinates.
     *
     * - Returns: `UIFocusInfo` containing focus details, or nil if no element has focus
     *
     * ## Focus Detection
     * Uses the accessibility API to query the system-wide focus state:
     * 1. **System Query**: Queries `kAXFocusedUIElementAttribute` on system-wide element
     * 2. **Element Analysis**: Extracts role, title, value, and geometric properties
     * 3. **Application Context**: Identifies the owning application and process
     * 4. **Coordinate Mapping**: Converts element bounds to screen coordinates
     *
     * ## Returned Information
     * The `UIFocusInfo` structure contains:
     * - **Element Properties**: role, title, value, and screen frame
     * - **Application Info**: name, bundle identifier, and process ID
     * - **Geometric Data**: element bounds in screen coordinates
     *
     * ## Use Cases
     * - **Focus Validation**: Verify expected element has focus before typing
     * - **Context Awareness**: Understand current input context for automation
     * - **Debugging**: Diagnose focus issues in automation workflows
     * - **State Tracking**: Monitor focus changes during complex interactions
     *
     * ## Performance
     * - **Query Time**: 5-20ms for accessibility system query
     * - **No Caching**: Always queries live system state
     * - **Thread Safety**: Must be called on main thread
     *
     * ## Example
     * ```swift
     * if let focusInfo = automation.getFocusedElement() {
     *     print("Focused element: \(focusInfo.role)")
     *     print("In application: \(focusInfo.applicationName)")
     *     print("Element title: \(focusInfo.title ?? "No title")")
     *     print("At coordinates: \(focusInfo.frame)")
     *
     *     // Check if it's a text field before typing
     *     if focusInfo.role == "AXTextField" {
     *         try await automation.type(text: "Hello", target: nil, ...)
     *     }
     * } else {
     *     print("No element currently has focus")
     * }
     * ```
     *
     * - Important: Requires Accessibility permission to query focused elements
     * - Note: Returns nil if no element has focus or accessibility query fails
     */
    @MainActor
    public func getFocusedElement() -> UIFocusInfo? {
        self.logger.debug("Getting focused element")

        // Get the system-wide focused element
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement)

        guard result == .success,
              let element = focusedElement
        else {
            self.logger.debug("No focused element found")
            return nil
        }

        let axElement = element as! AXUIElement
        let wrappedElement = Element(axElement)

        // Get element properties
        let role = wrappedElement.role() ?? "Unknown"
        let title = wrappedElement.title()
        let value = wrappedElement.stringValue()
        let frame = wrappedElement.frame() ?? .zero

        // Get application info
        var pid: pid_t = 0
        AXUIElementGetPid(axElement, &pid)

        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? "Unknown"
        let bundleId = app?.bundleIdentifier ?? "Unknown"

        return UIFocusInfo(
            role: role,
            title: title,
            value: value,
            frame: frame,
            applicationName: appName,
            bundleIdentifier: bundleId,
            processId: Int(pid))
    }

    // MARK: - Wait for Element

    /**
     * Wait for a UI element to become available with configurable timeout.
     *
     * - Parameters:
     *   - target: Element target to wait for (element ID, query, or coordinates)
     *   - timeout: Maximum time to wait in seconds (0.1-60s typical range)
     *   - sessionId: Session ID for element resolution (required for element ID targeting)
     * - Returns: `WaitForElementResult` indicating success/failure, found element, and wait time
     * - Throws: `PeekabooError` if invalid parameters or session not found
     *
     * ## Wait Behavior
     * - Polls every 100ms until element found or timeout reached
     * - For element IDs: checks session cache for element availability
     * - For queries: searches accessibility tree for matching elements
     * - For coordinates: returns immediately (coordinates don't need waiting)
     *
     * ## Examples
     * ```swift
     * // Wait for button to appear
     * let result = try await automation.waitForElement(
     *     target: .elementId("B1"),
     *     timeout: 5.0,
     *     sessionId: "session_123"
     * )
     * if result.found {
     *     print("Element found after \(result.waitTime)s")
     * }
     *
     * // Wait for element by text query
     * let submitResult = try await automation.waitForElement(
     *     target: .query("Submit"),
     *     timeout: 3.0,
     *     sessionId: "session_123"
     * )
     * ```
     */
    public func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?) async throws -> WaitForElementResult
    {
        self.logger.debug("Waiting for element - target: \(String(describing: target)), timeout: \(timeout)s")

        let startTime = Date()
        let deadline = startTime.addingTimeInterval(timeout)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds

        while Date() < deadline {
            // Check if element exists
            switch target {
            case let .elementId(id):
                if let sessionId,
                   let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
                   let element = detectionResult.elements.findById(id)
                {
                    let waitTime = Date().timeIntervalSince(startTime)
                    self.logger.debug("Found element \(id) after \(waitTime)s")
                    return WaitForElementResult(found: true, element: element, waitTime: waitTime)
                }

            case let .query(query):
                // Try to find in session first
                if let sessionId,
                   let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId)
                {
                    let queryLower = query.lowercased()
                    for element in detectionResult.elements.all {
                        let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                            element.value?.lowercased().contains(queryLower) ?? false

                        if matches, element.isEnabled {
                            let waitTime = Date().timeIntervalSince(startTime)
                            self.logger.debug("Found element matching '\(query)' after \(waitTime)s")
                            return WaitForElementResult(found: true, element: element, waitTime: waitTime)
                        }
                    }
                }

                // Try direct AX search
                let elementInfo = self.findElementByAccessibility(matching: query)

                if elementInfo != nil {
                    let waitTime = Date().timeIntervalSince(startTime)
                    let detectedElement = DetectedElement(
                        id: "wait_found",
                        type: .other,
                        label: elementInfo?.label ?? query,
                        value: nil,
                        bounds: elementInfo?.frame ?? .zero,
                        isEnabled: true,
                        isSelected: nil,
                        attributes: [:])

                    self.logger.debug("Found element via AX matching '\(query)' after \(waitTime)s")
                    return WaitForElementResult(found: true, element: detectedElement, waitTime: waitTime)
                }

            case .coordinates:
                // Coordinates don't need waiting
                let waitTime = Date().timeIntervalSince(startTime)
                return WaitForElementResult(found: true, element: nil, waitTime: waitTime)
            }

            // Wait before retry
            try await Task.sleep(nanoseconds: retryInterval)
        }

        // Timeout reached
        let waitTime = timeout
        self.logger.debug("Element not found after \(waitTime)s timeout")
        return WaitForElementResult(found: false, element: nil, waitTime: waitTime)
    }

    // MARK: - Private Helpers

    @MainActor
    private func findElementByAccessibility(matching query: String)
    -> (element: Element, frame: CGRect, label: String?)? {
        // Find the application at the mouse position
        guard let app = MouseLocationUtilities.findApplicationAtMouseLocation() else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        return self.searchElementRecursively(in: appElement, matching: query.lowercased())
    }

    @MainActor
    private func searchElementRecursively(
        in element: Element,
        matching query: String) -> (element: Element, frame: CGRect, label: String?)?
    {
        // Check current element
        let title = element.title()?.lowercased() ?? ""
        let label = element.label()?.lowercased() ?? ""
        let value = element.stringValue()?.lowercased() ?? ""
        let roleDescription = element.roleDescription()?.lowercased() ?? ""

        if title.contains(query) || label.contains(query) ||
            value.contains(query) || roleDescription.contains(query)
        {
            if let frame = element.frame() {
                let displayLabel = element.title() ?? element.label() ?? element.roleDescription()
                return (element, frame, displayLabel)
            }
        }

        // Search children
        if let children = element.children() {
            for child in children {
                if let found = searchElementRecursively(in: child, matching: query) {
                    return found
                }
            }
        }

        return nil
    }

    // MARK: - Find Element

    public func findElement(
        matching criteria: UIElementSearchCriteria,
        in appName: String?) async throws -> DetectedElement
    {
        self.logger.debug("Finding element matching criteria in app: \(appName ?? "any")")

        // Capture screenshot
        let captureResult: CaptureResult
        if let appName {
            // Try to find the application first
            let appService = ApplicationService()
            _ = try await appService.findApplication(identifier: appName)

            // Capture specific application
            captureResult = try await self.screenCaptureService.captureWindow(
                appIdentifier: appName,
                windowIndex: nil)
        } else {
            // Capture entire screen
            captureResult = try await self.screenCaptureService.captureScreen(displayIndex: nil)
        }

        // Detect elements in the screenshot
        let detectionResult = try await detectElements(
            in: captureResult.imageData,
            sessionId: nil,
            windowContext: nil)

        // Search for matching element
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

        // No matching element found
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
}

// MARK: - Supporting Types

/**
 * Comprehensive information about a focused UI element for automation workflows.
 *
 * `UIFocusInfo` encapsulates all relevant details about the currently focused UI element,
 * providing both element-specific properties and application context. This information
 * is essential for intelligent automation decisions and focus management.
 *
 * ## Element Properties
 * - **role**: Accessibility role (e.g., "AXTextField", "AXButton", "AXStaticText")
 * - **title**: Element title or accessibility label
 * - **value**: Current element value (text content for text fields)
 * - **frame**: Element bounds in screen coordinates
 *
 * ## Application Context
 * - **applicationName**: Human-readable application name
 * - **bundleIdentifier**: Application bundle ID for precise identification
 * - **processId**: System process ID for the owning application
 *
 * ## Usage Examples
 * ```swift
 * if let focus = automation.getFocusedElement() {
 *     // Check element type before interaction
 *     switch focus.role {
 *     case "AXTextField":
 *         print("Text field focused: \(focus.title ?? "Untitled")")
 *         // Safe to type text
 *     case "AXButton":
 *         print("Button focused: \(focus.title ?? "Untitled")")
 *         // Could trigger with Enter key
 *     default:
 *         print("Other element: \(focus.role)")
 *     }
 *
 *     // Application-specific behavior
 *     if focus.bundleIdentifier == "com.apple.Safari" {
 *         print("Focus is in Safari")
 *     }
 * }
 * ```
 *
 * - Important: All coordinate information is in screen coordinates (not window-relative)
 * - Note: Values may be nil if the element doesn't support that property
 * - Since: PeekabooCore 1.0.0
 */
public struct UIFocusInfo: Sendable {
    public let role: String
    public let title: String?
    public let value: String?
    public let frame: CGRect
    public let applicationName: String
    public let bundleIdentifier: String
    public let processId: Int

    public init(
        role: String,
        title: String?,
        value: String?,
        frame: CGRect,
        applicationName: String,
        bundleIdentifier: String,
        processId: Int)
    {
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.processId = processId
    }
}
