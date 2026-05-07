import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation

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
        let result = try await self.elementDetectionService.detectElements(
            in: imageData,
            snapshotId: snapshotId,
            windowContext: windowContext)
        if let snapshotId {
            try await self.snapshotManager.storeDetectionResult(snapshotId: snapshotId, result: result)
        }
        return result
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

    public func hotkey(keys: String, holdDuration: Int, targetProcessIdentifier: pid_t) async throws {
        self.logger.debug("Delegating targeted hotkey to HotkeyService")
        try await self.hotkeyService.hotkey(
            keys: keys,
            holdDuration: holdDuration,
            targetProcessIdentifier: targetProcessIdentifier)

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

    public func drag(_ request: DragOperationRequest) async throws {
        self.logger.debug("Delegating drag to GestureService")
        try await self.gestureService.drag(request)
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
}
