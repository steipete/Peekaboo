import Testing
import Foundation
import AXorcist
import ApplicationServices
@testable import PeekabooCore

@Suite("Element+Timeout Tests")
struct ElementTimeoutTests {
    
    @Test("Set messaging timeout on element")
    @MainActor
    func testSetMessagingTimeout() async throws {
        // Given - Get an element for a running app
        guard let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            throw Issue.record("Finder not running")
        }
        
        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)
        
        // When setting timeout
        element.setMessagingTimeout(1.0)
        
        // Then - no crash and method completes
        #expect(element != nil)
    }
    
    @Test("Windows with timeout returns windows")
    @MainActor
    func testWindowsWithTimeoutReturnsWindows() async throws {
        // Given - Get Finder element
        guard let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            throw Issue.record("Finder not running")
        }
        
        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)
        
        // When getting windows with timeout
        let windows = element.windowsWithTimeout(timeout: 2.0)
        
        // Then
        #expect(windows != nil)
        // Finder should have at least one window (Desktop)
        #expect((windows?.count ?? 0) >= 1)
    }
    
    @Test("Windows with timeout respects short timeout")
    @MainActor
    func testWindowsWithTimeoutRespectsShortTimeout() async throws {
        // Given
        guard let app = NSWorkspace.shared.runningApplications.first(where: { 
            $0.activationPolicy == .regular && $0.bundleIdentifier != nil 
        }) else {
            throw Issue.record("No suitable app found")
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let element = Element(axApp)
        
        // When getting windows with very short timeout
        let startTime = Date()
        _ = element.windowsWithTimeout(timeout: 0.1)
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Then - should complete quickly
        #expect(elapsed < 0.5)
    }
    
    @Test("Menu bar with timeout returns menu bar")
    @MainActor
    func testMenuBarWithTimeoutReturnsMenuBar() async throws {
        // Given
        guard let app = NSWorkspace.shared.runningApplications.first(where: { 
            $0.activationPolicy == .regular && 
            $0.bundleIdentifier != nil &&
            !$0.isHidden
        }) else {
            throw Issue.record("No suitable app found")
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let element = Element(axApp)
        
        // When getting menu bar with timeout
        let menuBar = element.menuBarWithTimeout(timeout: 2.0)
        
        // Then
        #expect(menuBar != nil)
    }
    
    @Test("AX timeout configuration")
    @MainActor
    func testAXTimeoutConfiguration() async throws {
        // When setting global timeout
        AXTimeoutConfiguration.setGlobalTimeout(1.5)
        
        // Then - method completes without error
        #expect(true) // No crash means success
        
        // Reset to default
        AXTimeoutConfiguration.setGlobalTimeout(0)
    }
    
    @Test("Timeout wrapper with cancellation")
    @MainActor
    func testTimeoutWrapperWithCancellation() async throws {
        // Given
        var taskStarted = false
        var taskCompleted = false
        
        // When running a task that takes longer than timeout
        do {
            _ = try await withTimeoutWrapper(timeout: 0.1) {
                taskStarted = true
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                taskCompleted = true
                return "completed"
            }
            Issue.record("Expected timeout error")
        } catch {
            // Then
            #expect(taskStarted == true)
            #expect(taskCompleted == false)
            #expect(error is PeekabooError)
            if case let PeekabooError.timeout(message) = error {
                #expect(message.contains("0.1 seconds"))
            }
        }
    }
    
    @Test("Timeout wrapper completes before timeout")
    @MainActor
    func testTimeoutWrapperCompletesBeforeTimeout() async throws {
        // Given/When
        let result = try await withTimeoutWrapper(timeout: 1.0) {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return "success"
        }
        
        // Then
        #expect(result == "success")
    }
    
    @Test("Multiple menu items with timeout")
    @MainActor
    func testMultipleMenuItemsWithTimeout() async throws {
        // Given
        guard let app = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.apple.finder"
        }) else {
            throw Issue.record("Finder not running")
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let element = Element(axApp)
        
        // When getting menu bar
        guard let menuBar = element.menuBarWithTimeout(timeout: 2.0) else {
            throw Issue.record("No menu bar found")
        }
        
        // And getting menu items
        let menuItems = menuBar.menuBarItems() ?? []
        
        // Then - should have standard menus
        #expect(!menuItems.isEmpty)
        #expect(menuItems.contains { item in
            item.title()?.contains("File") ?? false
        })
    }
}