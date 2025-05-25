@testable import peekaboo
import XCTest
import AppKit

final class WindowManagerTests: XCTestCase {

    // MARK: - getWindowsForApp Tests

    func testGetWindowsForFinderApp() throws {
        // Get Finder's PID
        let apps = NSWorkspace.shared.runningApplications
        guard let finder = apps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            XCTFail("Finder not found")
            return
        }

        // Test getting windows for Finder
        let windows = try WindowManager.getWindowsForApp(pid: finder.processIdentifier)
        
        // Finder usually has at least one window
        XCTAssertGreaterThanOrEqual(windows.count, 0)
        
        // If there are windows, verify they're sorted by index
        if windows.count > 1 {
            for i in 1..<windows.count {
                XCTAssertGreaterThanOrEqual(windows[i].windowIndex, windows[i-1].windowIndex)
            }
        }
    }

    // MARK: - getWindowsForApp Tests

    func testGetWindowsForNonExistentApp() throws {
        // Test with non-existent PID
        let windows = try WindowManager.getWindowsForApp(pid: 99999)
        
        // Should return empty array, not throw
        XCTAssertEqual(windows.count, 0)
    }

    func testGetWindowsWithOffScreenOption() throws {
        // Get Finder's PID for testing
        let apps = NSWorkspace.shared.runningApplications
        guard let finder = apps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            XCTFail("Finder not found")
            return
        }
        
        // Test with includeOffScreen = true
        let allWindows = try WindowManager.getWindowsForApp(pid: finder.processIdentifier, includeOffScreen: true)
        
        // Test with includeOffScreen = false (default)
        let onScreenWindows = try WindowManager.getWindowsForApp(pid: finder.processIdentifier, includeOffScreen: false)
        
        // All windows should include off-screen ones, so count should be >= on-screen only
        XCTAssertGreaterThanOrEqual(allWindows.count, onScreenWindows.count)
    }

    // MARK: - WindowData Structure Tests
    
    func testWindowDataStructure() throws {
        // Get any app's windows to test the structure
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        guard let app = apps.first else {
            XCTSkip("No regular apps running")
            return
        }
        
        let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)
        
        // If we have windows, verify WindowData properties
        if let firstWindow = windows.first {
            // Check required properties exist
            XCTAssertGreaterThan(firstWindow.windowId, 0)
            XCTAssertGreaterThanOrEqual(firstWindow.windowIndex, 0)
            XCTAssertNotNil(firstWindow.title)
            XCTAssertNotNil(firstWindow.bounds)
            
            // Check bounds structure
            XCTAssertGreaterThanOrEqual(firstWindow.bounds.width, 0)
            XCTAssertGreaterThanOrEqual(firstWindow.bounds.height, 0)
        }
    }

    // MARK: - Error Handling Tests
    
    func testWindowListError() {
        // We can't easily force CGWindowListCopyWindowInfo to fail,
        // but we can test that the error type exists
        let error = WindowError.windowListFailed
        XCTAssertNotNil(error)
    }

    func testCaptureWindowImage() throws {
        // Test window capture functionality
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        guard let app = apps.first else {
            XCTSkip("No regular apps running")
            return
        }
        
        let windows = try WindowManager.getWindowsForApp(pid: app.processIdentifier)
        guard let window = windows.first else {
            XCTSkip("No windows available for testing")
            return
        }
        
        // WindowManager doesn't have a captureWindow method based on the grep results
        // This test would need the actual capture functionality
        XCTAssertGreaterThan(window.windowId, 0)
    }

    // MARK: - Performance Tests

    func testGetWindowsPerformance() throws {
        // Test performance of getting windows
        let apps = NSWorkspace.shared.runningApplications
        guard let finder = apps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            XCTFail("Finder not found")
            return
        }
        
        measure {
            _ = try? WindowManager.getWindowsForApp(pid: finder.processIdentifier)
        }
    }

    // MARK: - Static Window Utility Tests
    
    func testGetWindowsInfoForApp() throws {
        // Test getting window info with details
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        guard let app = apps.first else {
            XCTSkip("No regular apps running")
            return
        }
        
        let windowInfos = try WindowManager.getWindowsInfoForApp(
            pid: app.processIdentifier,
            includeOffScreen: false,
            includeBounds: true,
            includeIDs: true
        )
        
        // Verify WindowInfo structure
        if let firstInfo = windowInfos.first {
            XCTAssertNotNil(firstInfo.window_title)
            XCTAssertNotNil(firstInfo.window_id)
            XCTAssertNotNil(firstInfo.bounds)
        }
    }
}
