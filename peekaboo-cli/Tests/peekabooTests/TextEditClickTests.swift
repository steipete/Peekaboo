import Testing
import Foundation
import ApplicationServices
@testable import peekaboo

@Suite("TextEdit Click Integration Tests", .tags(.localOnly))
struct TextEditClickTests {
    
    @Test("Click on TextEdit formatting controls")
    @MainActor
    func testFormattingControls() async throws {
        // This test requires TextEdit to be running and test host app
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw Issue.record("Skipping local-only test. Set RUN_LOCAL_TESTS=true to run.")
        }
        
        // Launch TextEdit
        let workspace = NSWorkspace.shared
        guard let textEdit = workspace.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.TextEdit" }) else {
            // Try to launch TextEdit
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            guard let textEditURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else {
                throw Issue.record("TextEdit not found")
            }
            
            _ = try await workspace.openApplication(at: textEditURL, configuration: config)
            try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
        }
        
        // Create a new document
        let scriptSource = """
        tell application "TextEdit"
            activate
            make new document
        end tell
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&error)
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        
        // Run see command to capture UI
        let seeCommand = try SeeCommand.parse(["--app", "TextEdit", "--annotate"])
        let seeResult = try await seeCommand.run()
        
        guard seeResult.success,
              let sessionId = seeResult.session_id else {
            throw Issue.record("Failed to create session")
        }
        
        // Test 1: Click on text area
        var clickCommand = try ClickCommand.parse(["--on", "T1", "--session", sessionId])
        var result = try await clickCommand.run()
        #expect(result.success == true)
        #expect(result.clickedElement?.contains("TextArea") == true)
        
        // Type some text
        let typeCommand = try TypeCommand.parse(["Test text for formatting"])
        _ = try await typeCommand.run()
        
        // Test 2: Click on Bold checkbox
        clickCommand = try ClickCommand.parse(["--on", "C1", "--session", sessionId])
        result = try await clickCommand.run()
        #expect(result.success == true)
        #expect(result.clickedElement?.contains("CheckBox") == true)
        
        // Test 3: Click on Italic checkbox
        clickCommand = try ClickCommand.parse(["--on", "C2", "--session", sessionId])
        result = try await clickCommand.run()
        #expect(result.success == true)
        
        // Test 4: Click on font dropdown
        clickCommand = try ClickCommand.parse(["--on", "G24", "--session", sessionId])
        result = try await clickCommand.run()
        #expect(result.success == true)
        #expect(result.clickedElement?.contains("PopUpButton") == true)
        
        // Close dropdown
        let hotkeyCommand = try HotkeyCommand.parse(["--keys", "escape"])
        _ = try await hotkeyCommand.run()
    }
    
    @Test("Text-based clicking in TextEdit")
    @MainActor
    func testTextBasedClicking() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw Issue.record("Skipping local-only test")
        }
        
        // Ensure TextEdit is active
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first?.activate(options: .activateIgnoringOtherApps)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create session
        let seeCommand = try SeeCommand.parse(["--app", "TextEdit"])
        let seeResult = try await seeCommand.run()
        
        guard seeResult.success else {
            throw Issue.record("Failed to create session")
        }
        
        // Test clicking by text content
        var clickCommand = try ClickCommand.parse(["Bold"])
        var result = try await clickCommand.run()
        
        // Should find and click on Bold checkbox or button
        if result.success {
            #expect(result.clickedElement?.lowercased().contains("bold") == true)
        }
        
        // Test clicking by partial text
        clickCommand = try ClickCommand.parse(["Hel"]) // Should match "Helvetica"
        result = try await clickCommand.run()
        
        if result.success {
            #expect(result.clickedElement != nil)
        }
    }
    
    @Test("Coordinate-based clicking in TextEdit")
    @MainActor
    func testCoordinateClicking() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw Issue.record("Skipping local-only test")
        }
        
        // Create session
        let seeCommand = try SeeCommand.parse(["--app", "TextEdit"])
        let seeResult = try await seeCommand.run()
        
        guard seeResult.success,
              let windowBounds = seeResult.window_bounds else {
            throw Issue.record("Failed to get window bounds")
        }
        
        // Click at center of window
        let centerX = windowBounds.minX + windowBounds.width / 2
        let centerY = windowBounds.minY + windowBounds.height / 2
        
        let clickCommand = try ClickCommand.parse(["--coords", "\(Int(centerX)),\(Int(centerY))"])
        let result = try await clickCommand.run()
        
        #expect(result.success == true)
        #expect(result.clickLocation?.x == centerX)
        #expect(result.clickLocation?.y == centerY)
    }
    
    @Test("Double-click to select word")
    @MainActor
    func testDoubleClick() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw Issue.record("Skipping local-only test")
        }
        
        // Setup TextEdit with some text
        let seeCommand = try SeeCommand.parse(["--app", "TextEdit"])
        _ = try await seeCommand.run()
        
        // Click on text area first
        var clickCommand = try ClickCommand.parse(["--on", "T1"])
        _ = try await clickCommand.run()
        
        // Type a word
        let typeCommand = try TypeCommand.parse(["DoubleClickTest"])
        _ = try await typeCommand.run()
        
        // Double-click to select the word
        clickCommand = try ClickCommand.parse(["--on", "T1", "--double"])
        let result = try await clickCommand.run()
        
        #expect(result.success == true)
        
        // Type to replace - if double-click worked, the word will be replaced
        let replaceCommand = try TypeCommand.parse(["Selected"])
        _ = try await replaceCommand.run()
    }
    
    @Test("Right-click context menu")
    @MainActor
    func testRightClick() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw Issue.record("Skipping local-only test")
        }
        
        // Create session
        let seeCommand = try SeeCommand.parse(["--app", "TextEdit"])
        _ = try await seeCommand.run()
        
        // Right-click on text area
        let clickCommand = try ClickCommand.parse(["--on", "T1", "--right"])
        let result = try await clickCommand.run()
        
        #expect(result.success == true)
        
        // Close context menu
        let hotkeyCommand = try HotkeyCommand.parse(["--keys", "escape"])
        _ = try await hotkeyCommand.run()
    }
    
    @Test("Click with wait-for element")
    @MainActor
    func testClickWithWaitFor() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw Issue.record("Skipping local-only test")
        }
        
        // This test simulates clicking on a menu item that triggers a dialog
        let seeCommand = try SeeCommand.parse(["--app", "TextEdit"])
        _ = try await seeCommand.run()
        
        // Click on File menu (using keyboard shortcut)
        let hotkeyCommand = try HotkeyCommand.parse(["--keys", "ctrl,f2"])
        _ = try await hotkeyCommand.run()
        
        try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
        
        // Type to navigate to File menu
        let typeCommand = try TypeCommand.parse(["File"])
        _ = try await typeCommand.run()
        
        let enterCommand = try HotkeyCommand.parse(["--keys", "enter"])
        _ = try await enterCommand.run()
        
        // Click on Save with wait-for the save dialog
        let clickCommand = try ClickCommand.parse(["Save", "--wait-for", "Save"])
        let result = try await clickCommand.run()
        
        if result.success {
            #expect(result.waitTime ?? 0 > 0)
        }
        
        // Close any open dialogs
        let escapeCommand = try HotkeyCommand.parse(["--keys", "escape"])
        _ = try await escapeCommand.run()
    }
    
    @Test("Click on different UI element types")
    @MainActor
    func testVariousElementTypes() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw Issue.record("Skipping local-only test")
        }
        
        let seeCommand = try SeeCommand.parse(["--app", "TextEdit", "--annotate"])
        let seeResult = try await seeCommand.run()
        
        guard seeResult.success,
              let sessionId = seeResult.session_id else {
            throw Issue.record("Failed to create session")
        }
        
        // Load session to check available elements
        let sessionCache = SessionCache()
        guard let sessionData = try? sessionCache.loadSession(sessionId) else {
            throw Issue.record("Failed to load session data")
        }
        
        // Test clicking on different element types
        for element in sessionData.uiMap where element.isActionable {
            // Skip window controls to avoid closing the window
            if element.label?.contains("close") == true ||
               element.label?.contains("minimize") == true {
                continue
            }
            
            let clickCommand = try ClickCommand.parse(["--on", element.id, "--session", sessionId])
            let result = try await clickCommand.run()
            
            if result.success {
                #expect(result.clickedElement != nil)
                
                // Small delay between clicks
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Close any popups that might have opened
                if element.role == "AXPopUpButton" || element.role == "AXMenuButton" {
                    let escapeCommand = try HotkeyCommand.parse(["--keys", "escape"])
                    _ = try await escapeCommand.run()
                }
            }
        }
    }
    
    @Test("Click performance")
    @MainActor
    func testClickPerformance() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            throw Issue.record("Skipping local-only test")
        }
        
        let seeCommand = try SeeCommand.parse(["--app", "TextEdit"])
        _ = try await seeCommand.run()
        
        // Measure time for multiple clicks
        let startTime = Date()
        let clickCount = 5
        
        for i in 1...clickCount {
            // Alternate between different checkboxes
            let elementId = "C\(((i - 1) % 4) + 1)"
            let clickCommand = try ClickCommand.parse(["--on", elementId])
            _ = try await clickCommand.run()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageTime = totalTime / Double(clickCount)
        
        // Clicks should be reasonably fast (under 500ms average)
        #expect(averageTime < 0.5)
    }
}

// Helper to check if TextEdit is available
extension TextEditClickTests {
    static func isTextEditAvailable() -> Bool {
        return NSWorkspace.shared.runningApplications.contains { 
            $0.bundleIdentifier == "com.apple.TextEdit" 
        }
    }
}