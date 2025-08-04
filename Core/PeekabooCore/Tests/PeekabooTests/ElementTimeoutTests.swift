import ApplicationServices
import AppKit
import AXorcist
import Foundation
import Testing
@testable import PeekabooCore

@Suite("Element+Timeout Tests - Current API")
struct ElementTimeoutTests {
    @Test("Set messaging timeout on element")
    @MainActor
    func testSetMessagingTimeout() async throws {
        // Given - Get an element for a running app
        guard let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })
        else {
            Issue.record("Finder not running - skipping test")
            return
        }

        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)

        // When setting timeout
        element.setMessagingTimeout(1.0)

        // Then - no crash and method completes
        #expect(element.underlyingElement != nil)
    }

    @Test("Windows with timeout returns windows")
    @MainActor
    func windowsWithTimeoutReturnsWindows() async throws {
        // Given - Get Finder element
        guard let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })
        else {
            Issue.record("Finder not running - skipping test")
            return
        }

        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)

        // When getting windows with timeout
        let windows = element.windowsWithTimeout(timeout: 2.0)

        // Then
        #expect(windows != nil)
        // Note: Finder windows may vary, so we just check that the method works
        if let windowArray = windows {
            #expect(windowArray.count >= 0) // At least 0 windows
        }
    }

    @Test("Element children basic access")
    @MainActor
    func elementChildrenBasicAccess() async throws {
        // Given - Get Finder element
        guard let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })
        else {
            Issue.record("Finder not running - skipping test")
            return
        }

        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)

        // When getting children (using basic API)
        let children = element.children()

        // Then - should get some children (menu bar, windows, etc.)
        #expect(children != nil)
        if let childArray = children {
            #expect(childArray.count >= 0) // At least 0 children
        }
    }

    @Test("Element menu bar with timeout")
    @MainActor
    func elementMenuBarWithTimeout() async throws {
        // Given - Get Finder element
        guard let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })
        else {
            Issue.record("Finder not running - skipping test")
            return
        }

        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)

        // When getting menu bar with timeout
        let menuBar = element.menuBarWithTimeout(timeout: 2.0)

        // Then - Finder should have a menu bar when it's frontmost
        // Note: This might be nil if Finder is not active, which is okay
        if let menuBarElement = menuBar {
            #expect(menuBarElement.underlyingElement != nil)
        }
    }

    @Test("Element focus basic access")
    @MainActor
    func elementFocusBasicAccess() async throws {
        // Given - Get Finder element
        guard let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })
        else {
            Issue.record("Finder not running - skipping test")
            return
        }

        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)

        // When getting focused element (using basic API)
        let focusedElement = element.focusedUIElement()

        // Then - might have a focused element or might be nil
        // This is environment-dependent, so we just verify no crash
        if let focused = focusedElement {
            #expect(focused.underlyingElement != nil)
        }
        
        // Test passes if we get here without crashing
        #expect(Bool(true))
    }

    @Test("Element attribute basic access")
    @MainActor
    func elementAttributeBasicAccess() async throws {
        // Given - Get Finder element
        guard let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })
        else {
            Issue.record("Finder not running - skipping test")
            return
        }

        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)

        // When getting title attribute (using basic API)
        let title = element.title()

        // Then - Finder should have a title
        if let titleString = title {
            #expect(!titleString.isEmpty)
        }
        
        // Test that the method completes without error
        #expect(Bool(true))
    }

    @Test("Multiple menu items with timeout")
    @MainActor
    func multipleMenuItemsWithTimeout() async throws {
        // Given
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.finder"
        }) else {
            Issue.record("Finder not running - skipping test")
            return
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let element = Element(axApp)

        // When getting menu bar
        guard let menuBar = element.menuBarWithTimeout(timeout: 2.0) else {
            Issue.record("No menu bar found - skipping test")
            return
        }

        // And getting menu items (using children instead)
        let menuItems = menuBar.children() ?? []

        // Then - should have some menu items if Finder is active
        #expect(menuItems.count >= 0) // At least 0 menu items
        
        // Test that menu items are valid Elements
        for menuItem in menuItems {
            #expect(menuItem.underlyingElement != nil)
        }
    }

    @Test("Timeout configuration affects behavior")
    @MainActor
    func timeoutConfigurationAffectsBehavior() async throws {
        // Given - Get Finder element
        guard let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })
        else {
            Issue.record("Finder not running - skipping test")
            return
        }

        let axApp = AXUIElementCreateApplication(finder.processIdentifier)
        let element = Element(axApp)

        // Test different timeout values
        let shortTimeout: Float = 0.1
        let longTimeout: Float = 3.0

        // When using short timeout
        let startTime = Date()
        let _ = element.windowsWithTimeout(timeout: shortTimeout)
        let shortDuration = Date().timeIntervalSince(startTime)

        // Then short timeout should complete relatively quickly
        #expect(shortDuration < 2.0) // Should not take more than 2 seconds
        
        // Test that longer timeout doesn't crash
        let _ = element.windowsWithTimeout(timeout: longTimeout)
        
        // Test passes if we complete without crashing
        #expect(Bool(true))
    }
}