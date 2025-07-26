import Testing
import Foundation
@testable import peekaboo
import PeekabooCore

@Suite("Enhanced Error Messages")
struct EnhancedErrorTests {
    
    // MARK: - Shell Command Errors
    
    @Test("Shell command not found shows exit code and error")
    func testShellCommandNotFound() async throws {
        let services = MockPeekabooServices()
        let agent = PeekabooAgentService(services: services)
        
        // Execute shell command that doesn't exist
        let result = try await agent.executeTask(
            "Run shell command 'nonexistentcommand --help'",
            dryRun: false
        )
        
        // Verify error contains exit code and stderr
        #expect(result.content.contains("exit code"))
        #expect(result.content.contains("command not found") || result.content.contains("not found"))
    }
    
    @Test("Shell command with stderr output")
    func testShellCommandStderr() async throws {
        let services = MockPeekabooServices()
        let agent = PeekabooAgentService(services: services)
        
        let result = try await agent.executeTask(
            "Run shell command 'ls /nonexistent/directory'",
            dryRun: false
        )
        
        #expect(result.content.contains("No such file or directory"))
        #expect(result.content.contains("Exit code: 1"))
    }
    
    @Test("Which command shows 'not found' message from stdout")
    func testWhichCommandNotFound() async throws {
        let services = MockPeekabooServices()
        let agent = PeekabooAgentService(services: services)
        
        // Mock shell tool to simulate 'which pandoc' output
        services.mockShellOutput = ShellOutput(
            stdout: "pandoc not found\n",
            stderr: "",
            exitCode: 1
        )
        
        let result = try await agent.executeTask(
            "Run shell command 'which pandoc'",
            dryRun: false
        )
        
        // Should show the actual "pandoc not found" message
        #expect(result.content.contains("pandoc not found"))
        #expect(result.content.contains("Exit code: 1"))
    }
    
    // MARK: - Application Launch Errors
    
    @Test("Launch app with typo shows fuzzy matches")
    func testLaunchAppFuzzyMatch() async throws {
        let services = MockPeekabooServices()
        services.mockApplications = [
            ServiceApplicationInfo(
                processIdentifier: 123,
                bundleIdentifier: "com.apple.Safari",
                name: "Safari",
                bundlePath: "/Applications/Safari.app",
                isActive: true,
                isHidden: false,
                windowCount: 1
            ),
            ServiceApplicationInfo(
                processIdentifier: 456,
                bundleIdentifier: "com.apple.SystemInformation",
                name: "System Information",
                bundlePath: "/Applications/Utilities/System Information.app",
                isActive: false,
                isHidden: false,
                windowCount: 0
            ),
            ServiceApplicationInfo(
                processIdentifier: 789,
                bundleIdentifier: "com.apple.Simulator",
                name: "Simulator",
                bundlePath: "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app",
                isActive: false,
                isHidden: false,
                windowCount: 0
            )
        ]
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Launch app 'Safary'", // Typo in Safari
            dryRun: false
        )
        
        // Should suggest Safari as closest match
        #expect(result.content.contains("Did you mean: Safari"))
        #expect(result.content.contains("launch_app \"Safari\""))
    }
    
    @Test("Launch completely unknown app shows available apps")
    func testLaunchUnknownApp() async throws {
        let services = MockPeekabooServices()
        services.mockApplications = [
            ServiceApplicationInfo(name: "Finder", bundleIdentifier: "com.apple.finder", processIdentifier: 100, isActive: true),
            ServiceApplicationInfo(name: "Safari", bundleIdentifier: "com.apple.Safari", processIdentifier: 123, isActive: true)
        ]
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Launch app 'CompletelyUnknownApp'",
            dryRun: false
        )
        
        #expect(result.content.contains("Available:"))
        #expect(result.content.contains("list_apps"))
    }
    
    // MARK: - Click Element Errors
    
    @Test("Click non-existent button shows available buttons")
    func testClickNonExistentButton() async throws {
        let services = MockPeekabooServices()
        
        // Mock detected elements
        let mockElements = DetectedElements(
            all: [
                DetectedElement(identifier: "B1", label: "Continue", type: .button, bounds: .zero),
                DetectedElement(identifier: "B2", label: "Cancel", type: .button, bounds: .zero),
                DetectedElement(identifier: "B3", label: "Save Draft", type: .button, bounds: .zero)
            ],
            buttons: [
                DetectedElement(identifier: "B1", label: "Continue", type: .button, bounds: .zero),
                DetectedElement(identifier: "B2", label: "Cancel", type: .button, bounds: .zero),
                DetectedElement(identifier: "B3", label: "Save Draft", type: .button, bounds: .zero)
            ],
            textFields: [],
            links: [],
            other: []
        )
        
        services.mockDetectionResult = DetectionResult(
            elements: mockElements,
            screenshot: Data(),
            metadata: TestDetectionMetadata(
                detectionTime: Date(),
                screenSize: CGSize(width: 1920, height: 1080),
                scaleFactor: 2.0
            )
        )
        
        let agent = PeekabooAgentService(services: services)
        
        // First capture screen to get session
        let captureResult = try await agent.executeTask(
            "Take a screenshot",
            dryRun: false
        )
        
        // Extract session ID from result
        let sessionId = extractSessionId(from: captureResult.content)
        
        // Try to click non-existent button
        let clickResult = try await agent.executeTask(
            "Click on 'Submit'",
            dryRun: false
        )
        
        // Verify error shows available buttons
        #expect(clickResult.content.contains("'Continue' (B1)"))
        #expect(clickResult.content.contains("'Cancel' (B2)"))
        #expect(clickResult.content.contains("Did you mean"))
        #expect(clickResult.content.contains("Try: click B1"))
    }
    
    @Test("Click without session suggests using see tool")
    func testClickWithoutSession() async throws {
        let services = MockPeekabooServices()
        let agent = PeekabooAgentService(services: services)
        
        let result = try await agent.executeTask(
            "Click on 'Submit'",
            dryRun: false
        )
        
        #expect(result.content.contains("Use 'see' tool first"))
    }
    
    // MARK: - Window Operation Errors
    
    @Test("Focus window for non-running app")
    func testFocusWindowAppNotRunning() async throws {
        let services = MockPeekabooServices()
        services.mockApplications = [
            ServiceApplicationInfo(name: "Safari", bundleIdentifier: "com.apple.Safari", processIdentifier: 123, isActive: true),
            ServiceApplicationInfo(name: "Chrome", bundleIdentifier: "com.google.Chrome", processIdentifier: 456, isActive: false)
        ]
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Focus window for 'Firefox'",
            dryRun: false
        )
        
        #expect(result.content.contains("not running"))
        #expect(result.content.contains("Launch the app first"))
    }
    
    @Test("Focus window for app with no windows")
    func testFocusWindowNoWindows() async throws {
        let services = MockPeekabooServices()
        services.mockApplications = [
            ServiceApplicationInfo(name: "TestApp", bundleIdentifier: "com.test.app", processIdentifier: 123, isActive: true)
        ]
        services.mockWindows = [] // No windows
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Focus window for 'TestApp'",
            dryRun: false
        )
        
        #expect(result.content.contains("App is running but has no windows"))
    }
    
    @Test("Focus minimized windows shows state")
    func testFocusMinimizedWindows() async throws {
        let services = MockPeekabooServices()
        services.mockApplications = [
            ServiceApplicationInfo(name: "TestApp", bundleIdentifier: "com.test.app", processIdentifier: 123, isActive: true)
        ]
        services.mockWindows = [
            ServiceWindowInfo(
                title: "Document 1",
                windowID: 1,
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isMinimized: true,
                isMainWindow: true
            )
        ]
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Focus window for 'TestApp'",
            dryRun: false
        )
        
        #expect(result.content.contains("minimized"))
        #expect(result.content.contains("will be restored"))
    }
    
    // MARK: - Type Operation Errors
    
    @Test("Type without focused field")
    func testTypeWithoutFocus() async throws {
        let services = MockPeekabooServices()
        services.mockFocusedElement = nil // No element focused
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Type 'Hello World'",
            dryRun: false
        )
        
        #expect(result.content.contains("No text field is currently focused"))
        #expect(result.content.contains("Click on a text field first"))
    }
    
    @Test("Type with non-editable element focused")
    func testTypeNonEditableElement() async throws {
        let services = MockPeekabooServices()
        services.mockFocusedElement = FocusedElementInfo(
            elementType: "button",
            title: "Submit",
            isEditable: false,
            bounds: CGRect(x: 0, y: 0, width: 100, height: 40)
        )
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Type 'Hello World'",
            dryRun: false
        )
        
        #expect(result.content.contains("Focused element: button"))
        #expect(result.content.contains("not a text input field"))
    }
    
    // MARK: - Hotkey Errors
    
    @Test("Invalid hotkey format with plus signs")
    func testHotkeyInvalidFormatPlus() async throws {
        let services = MockPeekabooServices()
        let agent = PeekabooAgentService(services: services)
        
        let result = try await agent.executeTask(
            "Press hotkey 'cmd+shift+a'",
            dryRun: false
        )
        
        #expect(result.content.contains("Use commas instead of '+'"))
        #expect(result.content.contains("cmd,shift,a"))
    }
    
    @Test("Empty hotkey shows examples")
    func testHotkeyEmpty() async throws {
        let services = MockPeekabooServices()
        let agent = PeekabooAgentService(services: services)
        
        let result = try await agent.executeTask(
            "Press hotkey ''",
            dryRun: false
        )
        
        #expect(result.content.contains("Valid comma-separated"))
        #expect(result.content.contains("cmd,c - Copy"))
        #expect(result.content.contains("cmd,v - Paste"))
    }
    
    // MARK: - Menu Operation Errors
    
    @Test("Menu item not found shows available menus")
    func testMenuItemNotFound() async throws {
        let services = MockPeekabooServices()
        services.mockMenuStructure = MenuStructure(
            application: ServiceApplicationInfo(name: "TestApp", bundleIdentifier: "com.test", processIdentifier: 123, isActive: true),
            menus: [
                Menu(title: "File", items: [
                    MenuItem(title: "New", isEnabled: true, submenu: []),
                    MenuItem(title: "Open", isEnabled: true, submenu: []),
                    MenuItem(title: "Save", isEnabled: true, submenu: [])
                ]),
                Menu(title: "Edit", items: [
                    MenuItem(title: "Copy", isEnabled: true, submenu: []),
                    MenuItem(title: "Paste", isEnabled: true, submenu: [])
                ])
            ],
            totalItems: 5
        )
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Click menu item 'File > NonExistent'",
            dryRun: false
        )
        
        #expect(result.content.contains("Available:"))
        #expect(result.content.contains("File > New"))
        #expect(result.content.contains("list_menus"))
    }
    
    @Test("Disabled menu item")
    func testDisabledMenuItem() async throws {
        let services = MockPeekabooServices()
        let agent = PeekabooAgentService(services: services)
        
        // Simulate clicking a disabled menu item
        services.mockError = PeekabooError.commandFailed("Menu item is disabled")
        
        let result = try await agent.executeTask(
            "Click menu item 'Edit > Undo'",
            dryRun: false
        )
        
        #expect(result.content.contains("disabled"))
        #expect(result.content.contains("currently disabled"))
    }
    
    // MARK: - Dialog Operation Errors
    
    @Test("Dialog click with no dialog present")
    func testDialogClickNoDialog() async throws {
        let services = MockPeekabooServices()
        services.mockActiveDialogs = [] // No dialogs
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Click dialog button 'OK'",
            dryRun: false
        )
        
        #expect(result.content.contains("No dialog window found"))
        #expect(result.content.contains("Ensure a dialog is open"))
    }
    
    @Test("Dialog button not found shows available buttons")
    func testDialogButtonNotFound() async throws {
        let services = MockPeekabooServices()
        services.mockActiveDialogs = [
            ActiveDialog(
                title: "Save Changes?",
                buttons: ["Save", "Don't Save", "Cancel"],
                windowID: 123
            )
        ]
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Click dialog button 'OK'",
            dryRun: false
        )
        
        #expect(result.content.contains("Available buttons"))
        #expect(result.content.contains("Save"))
        #expect(result.content.contains("Don't Save"))
        #expect(result.content.contains("Cancel"))
    }
    
    // MARK: - Permission Errors
    
    @Test("Screen capture permission denied")
    func testScreenCapturePermissionDenied() async throws {
        let services = MockPeekabooServices()
        services.mockPermissions = MockPermissions(
            screenRecording: false,
            accessibility: true
        )
        services.mockError = PeekabooError.permissionDenied("Screen Recording permission required")
        
        let agent = PeekabooAgentService(services: services)
        let result = try await agent.executeTask(
            "Take a screenshot",
            dryRun: false
        )
        
        #expect(result.content.contains("Permission denied"))
        #expect(result.content.contains("Screen Recording"))
        #expect(result.content.contains("System Settings > Privacy & Security"))
    }
    
    // MARK: - Find Element Errors
    
    @Test("Find element with no matches shows available types")
    func testFindElementNoMatches() async throws {
        let services = MockPeekabooServices()
        
        let mockElements = DetectedElements(
            all: [],
            buttons: [
                DetectedElement(identifier: "B1", label: "Submit", type: .button, bounds: .zero)
            ],
            textFields: [
                DetectedElement(identifier: "T1", label: "Email", type: .textField, bounds: .zero)
            ],
            links: [],
            other: []
        )
        
        services.mockDetectionResult = DetectionResult(
            elements: mockElements,
            screenshot: Data(),
            metadata: TestDetectionMetadata(
                detectionTime: Date(),
                screenSize: CGSize(width: 1920, height: 1080),
                scaleFactor: 2.0
            )
        )
        
        let agent = PeekabooAgentService(services: services)
        
        // First capture screen
        _ = try await agent.executeTask("Take a screenshot", dryRun: false)
        
        // Try to find non-existent element type
        let result = try await agent.executeTask(
            "Find elements of type 'link'",
            dryRun: false
        )
        
        #expect(result.content.contains("No 'link' elements found"))
        #expect(result.content.contains("button (1)"))
        #expect(result.content.contains("textField (1)"))
    }
    
    // MARK: - Helper Functions
    
    private func extractSessionId(from content: String) -> String? {
        // Extract session ID from agent output
        if let range = content.range(of: "sessionId: ") {
            let afterSessionId = content[range.upperBound...]
            if let endRange = afterSessionId.firstIndex(where: { $0.isNewline || $0 == "," || $0 == "}" }) {
                return String(afterSessionId[..<endRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}

// MARK: - Mock Services

// @available not needed for test helpers
class MockPeekabooServices: @unchecked Sendable {
    var mockApplications: [ServiceApplicationInfo] = []
    var mockWindows: [ServiceWindowInfo] = []
    var mockDetectionResult: DetectionResult?
    var mockFocusedElement: FocusedElementInfo?
    var mockMenuStructure: MenuStructure?
    var mockActiveDialogs: [ActiveDialog] = []
    var mockPermissions: MockPermissions?
    var mockError: Error?
    var mockShellOutput: ShellOutput?
    
    override init() {
        super.init()
        
        // Override services with mocks
        self.applications = MockApplicationService(parent: self)
        self.windows = MockWindowService(parent: self)
        self.automation = MockAutomationService(parent: self)
        self.sessions = MockSessionService(parent: self)
        self.menu = MockMenuService(parent: self)
        self.dialogs = MockDialogService(parent: self)
        self.permissions = mockPermissions ?? MockPermissions()
        self.screenCapture = MockScreenCaptureService(parent: self)
        self.process = MockProcessService(parent: self)
    }
}

struct MockPermissions: PermissionsServiceProtocol {
    var screenRecording: Bool = true
    var accessibility: Bool = true
    
    func hasScreenRecordingPermission() async -> Bool { screenRecording }
    func hasAccessibilityPermission() async -> Bool { accessibility }
    func requestScreenRecordingPermission() async -> Bool { screenRecording }
    func requestAccessibilityPermission() async -> Bool { accessibility }
}

// @available not needed for test helpers
class MockApplicationService: ApplicationServiceProtocol, @unchecked Sendable {
    weak var parent: MockPeekabooServices?
    
    init(parent: MockPeekabooServices) {
        self.parent = parent
    }
    
    func listApplications() async throws -> [ServiceApplicationInfo] {
        if let error = parent?.mockError { throw error }
        return parent?.mockApplications ?? []
    }
    
    func listWindows(for appName: String) async throws -> [ServiceWindowInfo] {
        if let error = parent?.mockError { throw error }
        
        // Check if app exists
        guard parent?.mockApplications.contains(where: { $0.name == appName }) == true else {
            throw PeekabooError.appNotFound(appName)
        }
        
        return parent?.mockWindows ?? []
    }
    
    func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        if let error = parent?.mockError { throw error }
        return parent?.mockApplications.first(where: { $0.isActive }) ?? 
               ServiceApplicationInfo(name: "Finder", bundleIdentifier: "com.apple.finder", processIdentifier: 1, isActive: true)
    }
    
    func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        if let error = parent?.mockError { throw error }
        
        // Check for exact match
        if let app = parent?.mockApplications.first(where: { $0.name == identifier || $0.bundleIdentifier == identifier }) {
            return app
        }
        
        throw PeekabooError.appNotFound(identifier)
    }
}

// @available not needed for test helpers
class MockWindowService: WindowManagementServiceProtocol, @unchecked Sendable {
    weak var parent: MockPeekabooServices?
    
    init(parent: MockPeekabooServices) {
        self.parent = parent
    }
    
    func focusWindow(target: WindowTarget) async throws {
        if let error = parent?.mockError { throw error }
        
        switch target {
        case .application(let appName):
            guard parent?.mockApplications.contains(where: { $0.name == appName }) == true else {
                throw PeekabooError.appNotFound(appName)
            }
            
            if parent?.mockWindows.isEmpty == true {
                throw PeekabooError.windowNotFound
            }
        default:
            break
        }
    }
    
    func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        if let error = parent?.mockError { throw error }
        try await focusWindow(target: target) // Same validation
    }
    
    func closeWindow(target: WindowTarget) async throws {
        if let error = parent?.mockError { throw error }
    }
    
    func minimizeWindow(target: WindowTarget) async throws {
        if let error = parent?.mockError { throw error }
    }
    
    func maximizeWindow(target: WindowTarget) async throws {
        if let error = parent?.mockError { throw error }
    }
    
    func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        if let error = parent?.mockError { throw error }
    }
}

// @available not needed for test helpers
class MockAutomationService: UIAutomationServiceProtocol, @unchecked Sendable {
    weak var parent: MockPeekabooServices?
    
    init(parent: MockPeekabooServices) {
        self.parent = parent
    }
    
    func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        if let error = parent?.mockError { throw error }
        
        switch target {
        case .query(let text):
            // Check if element exists
            if let detection = parent?.mockDetectionResult {
                let found = detection.elements.all.contains { element in
                    element.label?.contains(text) == true
                }
                if !found {
                    throw PeekabooError.elementNotFound("Element '\(text)' not found")
                }
            } else {
                throw PeekabooError.elementNotFound("No elements detected")
            }
        default:
            break
        }
    }
    
    func type(text: String, target: String?, clearExisting: Bool, typingDelay: Int, sessionId: String?) async throws {
        if let error = parent?.mockError { throw error }
        
        if parent?.mockFocusedElement == nil {
            throw PeekabooError.commandFailed("No element is focused")
        }
    }
    
    func hotkey(keys: String, holdDuration: Int) async throws {
        if let error = parent?.mockError { throw error }
        
        if keys.isEmpty {
            throw PeekabooError.invalidInput("Invalid key combination")
        }
        
        if keys.contains("+") {
            throw PeekabooError.invalidInput("Invalid key format")
        }
    }
    
    func scroll(direction: ScrollDirection, amount: Int, target: String?, smooth: Bool, delay: Int, sessionId: String?) async throws {
        if let error = parent?.mockError { throw error }
    }
    
    func detectElements(in imageData: Data, sessionId: String) async throws -> DetectionResult {
        if let error = parent?.mockError { throw error }
        return parent?.mockDetectionResult ?? DetectionResult(
            elements: DetectedElements(all: [], buttons: [], textFields: [], links: [], other: []),
            screenshot: imageData,
            metadata: TestDetectionMetadata(
                detectionTime: Date(),
                screenSize: CGSize(width: 1920, height: 1080),
                scaleFactor: 2.0
            )
        )
    }
    
    func getFocusedElement() -> FocusedElementInfo? {
        return parent?.mockFocusedElement
    }
}

// @available not needed for test helpers
class MockSessionService: SessionsServiceProtocol, @unchecked Sendable {
    weak var parent: MockPeekabooServices?
    private var sessions: [String: DetectionResult] = [:]
    
    init(parent: MockPeekabooServices) {
        self.parent = parent
    }
    
    func storeDetectionResult(sessionId: String, result: DetectionResult) async throws {
        sessions[sessionId] = result
    }
    
    func getDetectionResult(sessionId: String) async throws -> DetectionResult? {
        return sessions[sessionId] ?? parent?.mockDetectionResult
    }
    
    func findElements(sessionId: String, matching query: String) async throws -> [AXElement] {
        // Simple mock implementation
        return []
    }
    
    func clearSession(sessionId: String) async throws {
        sessions.removeValue(forKey: sessionId)
    }
}

// @available not needed for test helpers
class MockMenuService: MenuServiceProtocol, @unchecked Sendable {
    weak var parent: MockPeekabooServices?
    
    init(parent: MockPeekabooServices) {
        self.parent = parent
    }
    
    func clickMenuItem(app: String, itemPath: String) async throws {
        if let error = parent?.mockError { throw error }
        
        if error.localizedDescription.contains("disabled") {
            return // Already set
        }
        
        throw PeekabooError.commandFailed("Menu item not found")
    }
    
    func listMenus(for appName: String) async throws -> MenuStructure {
        if let error = parent?.mockError { throw error }
        return parent?.mockMenuStructure ?? MenuStructure(
            application: ServiceApplicationInfo(name: appName, bundleIdentifier: "", processIdentifier: 0, isActive: true),
            menus: [],
            totalItems: 0
        )
    }
    
    func listFrontmostMenus() async throws -> MenuStructure {
        return try await listMenus(for: "Frontmost")
    }
}

// @available not needed for test helpers
class MockDialogService: DialogServiceProtocol, @unchecked Sendable {
    weak var parent: MockPeekabooServices?
    
    init(parent: MockPeekabooServices) {
        self.parent = parent
    }
    
    func findActiveDialog(windowTitle: String?) async throws -> DialogInfo {
        if let error = parent?.mockError { throw error }
        
        // Return a mock dialog info
        return DialogInfo(
            title: "Mock Dialog",
            role: "AXDialog",
            subrole: nil,
            isFileDialog: false,
            bounds: CGRect(x: 100, y: 100, width: 400, height: 300)
        )
    }
    
    func clickButton(buttonText: String, windowTitle: String?) async throws -> DialogActionResult {
        if let error = parent?.mockError { throw error }
        
        // Simplified mock implementation
        if buttonText == "NonExistentButton" {
            throw PeekabooError.commandFailed("Button not found")
        }
        
        return DialogActionResult(
            success: true,
            action: .clickButton,
            details: ["button": buttonText]
        )
    }
    
    func enterText(text: String, fieldIdentifier: String?, clearExisting: Bool, windowTitle: String?) async throws -> DialogActionResult {
        if let error = parent?.mockError { throw error }
        return DialogActionResult(
            success: true,
            action: .enterText,
            details: ["text": text]
        )
    }
    
    func handleFileDialog(path: String?, filename: String?, actionButton: String) async throws -> DialogActionResult {
        if let error = parent?.mockError { throw error }
        return DialogActionResult(
            success: true,
            action: .handleFileDialog,
            details: [:]
        )
    }
    
    func dismissDialog(force: Bool, windowTitle: String?) async throws -> DialogActionResult {
        if let error = parent?.mockError { throw error }
        return DialogActionResult(
            success: true,
            action: .dismiss,
            details: [:]
        )
    }
    
    func listDialogElements(windowTitle: String?) async throws -> DialogElements {
        if let error = parent?.mockError { throw error }
        return DialogElements(
            dialogInfo: DialogInfo(
                title: "Mock Dialog",
                role: "AXDialog",
                bounds: CGRect(x: 100, y: 100, width: 400, height: 300)
            ),
            buttons: [DialogButton(title: "OK"), DialogButton(title: "Cancel")]
        )
    }
}

// @available not needed for test helpers
class MockScreenCaptureService: ScreenCaptureServiceProtocol, @unchecked Sendable {
    weak var parent: MockPeekabooServices?
    
    init(parent: MockPeekabooServices) {
        self.parent = parent
    }
    
    func captureScreen(displayIndex: Int?) async throws -> CaptureResult {
        if let error = parent?.mockError { throw error }
        
        return CaptureResult(
            imageData: Data(),
            savedPath: "/tmp/screenshot.png",
            metadata: CaptureMetadata(
                size: CGSize(width: 1920, height: 1080),
                scaleFactor: 2.0,
                captureMode: .screen,
                displayIndex: displayIndex ?? 0,
                applicationInfo: nil
            )
        )
    }
    
    func captureFrontmost() async throws -> CaptureResult {
        if let error = parent?.mockError { throw error }
        
        return CaptureResult(
            imageData: Data(),
            savedPath: "/tmp/screenshot.png",
            metadata: CaptureMetadata(
                size: CGSize(width: 800, height: 600),
                scaleFactor: 2.0,
                captureMode: .window,
                displayIndex: 0,
                applicationInfo: ServiceApplicationInfo(
                    name: "TestApp",
                    bundleIdentifier: "com.test.app",
                    processIdentifier: 123,
                    isActive: true
                )
            )
        )
    }
    
    func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult {
        if let error = parent?.mockError { throw error }
        
        // Check if app exists
        guard parent?.mockApplications.contains(where: { $0.name == appIdentifier }) == true else {
            throw PeekabooError.appNotFound(appIdentifier)
        }
        
        return CaptureResult(
            imageData: Data(),
            savedPath: "/tmp/screenshot.png",
            metadata: CaptureMetadata(
                size: CGSize(width: 800, height: 600),
                scaleFactor: 2.0,
                captureMode: .window,
                displayIndex: 0,
                applicationInfo: ServiceApplicationInfo(
                    name: appIdentifier,
                    bundleIdentifier: "com.app.bundle",
                    processIdentifier: 123,
                    isActive: true
                )
            )
        )
    }
    
    func hasScreenRecordingPermission() async -> Bool {
        return true
    }
    
    func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        if let error = parent?.mockError { throw error }
        
        return CaptureResult(
            imageData: Data(),
            savedPath: "/tmp/screenshot.png",
            metadata: CaptureMetadata(
                size: rect.size,
                scaleFactor: 2.0,
                captureMode: .area,
                displayIndex: 0,
                applicationInfo: nil
            )
        )
    }
}

// ActiveDialog is already defined in TestSupport/ActiveDialog.swift

enum DialogAction: String {
    case clicked
    case typed
}

struct DialogResult {
    let success: Bool
    let action: DialogAction
    let details: String
}

struct ShellOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

// @available not needed for test helpers
class MockProcessService: TestProcessServiceProtocol, @unchecked Sendable {
    weak var parent: MockPeekabooServices?
    
    init(parent: MockPeekabooServices) {
        self.parent = parent
    }
    
    func execute(command: String, arguments: [String], environment: [String: String]?, currentDirectory: String?) async throws -> ProcessResult {
        // If we have mock shell output, return it
        if let mockOutput = parent?.mockShellOutput {
            return ProcessResult(
                output: mockOutput.stdout,
                errorOutput: mockOutput.stderr,
                exitCode: mockOutput.exitCode
            )
        }
        
        // Default implementation for common commands
        if command.contains("which") {
            let target = arguments.last ?? ""
            if ["ls", "cat", "echo", "pwd"].contains(target) {
                return ProcessResult(output: "/usr/bin/\(target)\n", errorOutput: "", exitCode: 0)
            } else {
                return ProcessResult(output: "\(target) not found\n", errorOutput: "", exitCode: 1)
            }
        }
        
        // Default error
        return ProcessResult(
            output: "",
            errorOutput: "command not found",
            exitCode: 127
        )
    }
    
    func executeScript(script: String, language: ScriptLanguage) async throws -> ProcessResult {
        return ProcessResult(output: "", errorOutput: "", exitCode: 0)
    }
}

// ProcessResult is now defined in TestSupport/ProcessServiceProtocol.swift