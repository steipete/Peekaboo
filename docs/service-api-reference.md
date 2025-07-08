# PeekabooCore Service API Reference

This document provides a comprehensive reference for all services available in PeekabooCore. These services are used by both the CLI and Mac app to provide consistent functionality with optimal performance.

## Table of Contents

1. [ScreenCaptureService](#screencaptureservice)
2. [ApplicationService](#applicationservice)
3. [WindowManagementService](#windowmanagementservice)
4. [UIAutomationService](#uiautomationservice)
5. [MenuService](#menuservice)
6. [DockService](#dockservice)
7. [ProcessService](#processservice)
8. [DialogService](#dialogservice)
9. [FileService](#fileservice)
10. [SessionManager](#sessionmanager)
11. [ConfigurationManager](#configurationmanager)
12. [EventGenerator](#eventgenerator)

---

## ScreenCaptureService

Handles all screen capture operations including windows, screens, and areas.

### Methods

#### `captureWindow(element:savePath:options:)`
Captures a screenshot of a specific window.

```swift
func captureWindow(
    element: Element,
    savePath: String,
    options: CaptureOptions = .init()
) async throws -> CaptureResult
```

**Parameters:**
- `element`: The window element to capture
- `savePath`: Path where the image should be saved
- `options`: Capture options (format, quality, etc.)

**Returns:** `CaptureResult` containing capture metadata

**Example:**
```swift
let result = try await service.captureWindow(
    element: windowElement,
    savePath: "~/Desktop/window.png"
)
```

#### `captureScreen(displayIndex:savePath:options:)`
Captures a full screen or specific display.

```swift
func captureScreen(
    displayIndex: Int = 0,
    savePath: String,
    options: CaptureOptions = .init()
) async throws -> CaptureResult
```

#### `captureArea(rect:savePath:options:)`
Captures a specific rectangular area of the screen.

```swift
func captureArea(
    rect: CGRect,
    savePath: String,
    options: CaptureOptions = .init()
) async throws -> CaptureResult
```

#### `captureAllWindows(for:savePath:options:)`
Captures all windows for a specific application.

```swift
func captureAllWindows(
    for app: RunningApplication,
    savePath: String,
    options: CaptureOptions = .init()
) async throws -> [CaptureResult]
```

---

## ApplicationService

Manages application lifecycle and information.

### Methods

#### `listApplications()`
Lists all running applications.

```swift
func listApplications() -> [RunningApplication]
```

**Returns:** Array of running applications with metadata

#### `findApplication(identifier:)`
Finds an application by name or bundle ID.

```swift
func findApplication(identifier: String) throws -> RunningApplication
```

**Parameters:**
- `identifier`: App name or bundle identifier

**Throws:** `ApplicationError.notFound` if not found

#### `launchApplication(identifier:)`
Launches an application.

```swift
func launchApplication(identifier: String) async throws -> RunningApplication
```

#### `quitApplication(_:force:)`
Quits an application gracefully or forcefully.

```swift
func quitApplication(_ app: RunningApplication, force: Bool = false) async throws
```

#### `hideApplication(_:)`
Hides an application.

```swift
func hideApplication(_ app: RunningApplication) async throws
```

#### `unhideApplication(_:)`
Shows a hidden application.

```swift
func unhideApplication(_ app: RunningApplication) async throws
```

---

## WindowManagementService

Handles window manipulation and queries.

### Methods

#### `listWindows(for:)`
Lists all windows for an application.

```swift
func listWindows(for app: RunningApplication) throws -> [WindowInfo]
```

#### `findWindow(app:title:index:)`
Finds a specific window by title or index.

```swift
func findWindow(
    app: RunningApplication,
    title: String? = nil,
    index: Int? = nil
) throws -> Element
```

#### `closeWindow(_:)`
Closes a window.

```swift
func closeWindow(_ window: Element) async throws
```

#### `minimizeWindow(_:)`
Minimizes a window.

```swift
func minimizeWindow(_ window: Element) async throws
```

#### `maximizeWindow(_:)`
Maximizes a window.

```swift
func maximizeWindow(_ window: Element) async throws
```

#### `moveWindow(_:to:)`
Moves a window to a specific position.

```swift
func moveWindow(_ window: Element, to position: CGPoint) async throws
```

#### `resizeWindow(_:to:)`
Resizes a window.

```swift
func resizeWindow(_ window: Element, to size: CGSize) async throws
```

#### `focusWindow(_:)`
Brings a window to the front and focuses it.

```swift
func focusWindow(_ window: Element) async throws
```

---

## UIAutomationService

Provides UI element interaction and automation.

### Methods

#### `findElement(matching:in:timeout:)`
Finds UI elements matching criteria.

```swift
func findElement(
    matching criteria: ElementCriteria,
    in container: Element? = nil,
    timeout: TimeInterval = 5.0
) async throws -> Element
```

#### `clickElement(_:at:clickCount:)`
Clicks on a UI element.

```swift
func clickElement(
    _ element: Element,
    at point: CGPoint? = nil,
    clickCount: Int = 1
) async throws
```

#### `typeText(_:in:clearFirst:)`
Types text into an element.

```swift
func typeText(
    _ text: String,
    in element: Element? = nil,
    clearFirst: Bool = false
) async throws
```

#### `scrollElement(_:direction:amount:)`
Scrolls within an element.

```swift
func scrollElement(
    _ element: Element,
    direction: ScrollDirection,
    amount: CGFloat
) async throws
```

#### `dragElement(from:to:duration:)`
Performs a drag operation.

```swift
func dragElement(
    from startPoint: CGPoint,
    to endPoint: CGPoint,
    duration: TimeInterval = 0.5
) async throws
```

#### `swipeElement(_:direction:distance:)`
Performs a swipe gesture.

```swift
func swipeElement(
    _ element: Element,
    direction: SwipeDirection,
    distance: CGFloat
) async throws
```

---

## MenuService

Handles menu bar and context menu interactions.

### Methods

#### `clickMenuItem(app:menuPath:)`
Clicks a menu item by path.

```swift
func clickMenuItem(
    app: RunningApplication,
    menuPath: [String]
) async throws
```

**Example:**
```swift
try await service.clickMenuItem(
    app: app,
    menuPath: ["File", "Save As..."]
)
```

#### `listMenuItems(app:)`
Lists all menu items for an application.

```swift
func listMenuItems(app: RunningApplication) throws -> [MenuItemInfo]
```

#### `openContextMenu(at:)`
Opens a context menu at a specific location.

```swift
func openContextMenu(at point: CGPoint) async throws
```

---

## DockService

Manages Dock interactions.

### Methods

#### `listDockItems()`
Lists all items in the Dock.

```swift
func listDockItems() throws -> [DockItem]
```

#### `clickDockItem(identifier:)`
Clicks a Dock item.

```swift
func clickDockItem(identifier: String) async throws
```

#### `rightClickDockItem(identifier:)`
Right-clicks a Dock item to show its menu.

```swift
func rightClickDockItem(identifier: String) async throws
```

---

## ProcessService

Manages system processes and shell commands.

### Methods

#### `runCommand(_:arguments:environment:currentDirectory:)`
Executes a shell command.

```swift
func runCommand(
    _ command: String,
    arguments: [String] = [],
    environment: [String: String]? = nil,
    currentDirectory: String? = nil
) async throws -> ProcessResult
```

#### `killProcess(pid:signal:)`
Terminates a process.

```swift
func killProcess(pid: Int32, signal: Int32 = SIGTERM) throws
```

#### `checkProcessRunning(name:)`
Checks if a process is running.

```swift
func checkProcessRunning(name: String) -> Bool
```

---

## DialogService

Handles system dialogs and alerts.

### Methods

#### `findDialog(withTitle:timeout:)`
Finds a dialog by title.

```swift
func findDialog(
    withTitle title: String? = nil,
    timeout: TimeInterval = 5.0
) async throws -> Element
```

#### `clickDialogButton(_:in:)`
Clicks a button in a dialog.

```swift
func clickDialogButton(
    _ buttonTitle: String,
    in dialog: Element
) async throws
```

#### `dismissDialog(_:)`
Dismisses a dialog using keyboard shortcuts.

```swift
func dismissDialog(_ dialog: Element) async throws
```

#### `handleFileDialog(_:path:)`
Handles file selection dialogs.

```swift
func handleFileDialog(
    _ dialog: Element,
    path: String
) async throws
```

---

## FileService

Provides file system operations.

### Methods

#### `cleanFiles(at:matching:dryRun:)`
Cleans files matching criteria.

```swift
func cleanFiles(
    at path: String,
    matching criteria: CleanCriteria,
    dryRun: Bool = false
) async throws -> CleanResult
```

#### `listFiles(at:recursive:)`
Lists files in a directory.

```swift
func listFiles(
    at path: String,
    recursive: Bool = false
) throws -> [FileInfo]
```

#### `createDirectory(at:)`
Creates a directory.

```swift
func createDirectory(at path: String) throws
```

---

## SessionManager

Manages automation sessions for the Mac app.

### Properties

```swift
var currentSession: Session? { get }
var isSessionActive: Bool { get }
```

### Methods

#### `startSession(mode:)`
Starts a new automation session.

```swift
func startSession(mode: SessionMode) async throws -> Session
```

#### `endSession()`
Ends the current session.

```swift
func endSession() async
```

#### `executeInSession(_:)`
Executes a block within the current session context.

```swift
func executeInSession<T>(_ block: () async throws -> T) async throws -> T
```

---

## ConfigurationManager

Manages application configuration.

### Properties

```swift
static let shared: ConfigurationManager
var currentConfiguration: Configuration { get }
```

### Methods

#### `loadConfiguration()`
Loads configuration from disk.

```swift
func loadConfiguration() -> Configuration
```

#### `saveConfiguration(_:)`
Saves configuration to disk.

```swift
func saveConfiguration(_ config: Configuration) throws
```

#### `resetToDefaults()`
Resets configuration to defaults.

```swift
func resetToDefaults() throws
```

---

## EventGenerator

Low-level event generation for automation.

### Methods

#### `createMouseEvent(type:at:)`
Creates mouse events.

```swift
static func createMouseEvent(
    type: CGEventType,
    at point: CGPoint
) -> CGEvent?
```

#### `createKeyboardEvent(keyCode:down:)`
Creates keyboard events.

```swift
static func createKeyboardEvent(
    keyCode: UInt16,
    down: Bool
) -> CGEvent?
```

#### `typeText(_:)`
Types text using keyboard events.

```swift
static func typeText(_ text: String) async throws
```

---

## Error Handling

All services throw typed errors for better error handling:

```swift
enum ScreenCaptureError: Error {
    case permissionDenied
    case invalidWindow
    case captureF ailed
    case fileWriteError(Error)
}

enum ApplicationError: Error {
    case notFound(String)
    case ambiguousIdentifier([RunningApplication])
    case launchFailed(Error)
}

enum UIAutomationError: Error {
    case elementNotFound
    case interactionFailed
    case timeout
}
```

## Usage Example

Here's a complete example showing how to use multiple services together:

```swift
import PeekabooCore

// Initialize services
let appService = ApplicationService()
let windowService = WindowManagementService()
let captureService = ScreenCaptureService()
let uiService = UIAutomationService()

// Find and focus Safari
let safari = try appService.findApplication(identifier: "Safari")
let windows = try windowService.listWindows(for: safari)
if let firstWindow = windows.first {
    try await windowService.focusWindow(firstWindow.element)
}

// Capture the window
let result = try await captureService.captureWindow(
    element: firstWindow.element,
    savePath: "~/Desktop/safari.png"
)

// Click on a button
let criteria = ElementCriteria(role: .button, title: "Reload")
let button = try await uiService.findElement(matching: criteria)
try await uiService.clickElement(button)
```

## Performance Notes

- Services are designed to be lightweight and efficient
- They eliminate process spawning overhead compared to CLI invocations
- All async operations use Swift's native concurrency
- Services maintain minimal state for optimal performance
- The Mac app sees 100x+ performance improvement using services directly

## Thread Safety

- All services are thread-safe and can be used from any thread
- UI operations are automatically dispatched to the main thread
- Async methods use Swift's concurrency model for safety
- Shared state is protected with appropriate synchronization