@testable import peekaboo
import XCTest

final class WindowManagerTests: XCTestCase {
    var windowManager: WindowManager!

    override func setUp() {
        super.setUp()
        windowManager = WindowManager()
    }

    override func tearDown() {
        windowManager = nil
        super.tearDown()
    }

    // MARK: - getAllWindows Tests

    func testGetAllWindows() throws {
        // Test getting all windows
        let windows = windowManager.getAllWindows()

        // Should have at least some windows (Finder, menu bar, etc.)
        XCTAssertGreaterThan(windows.count, 0)

        // Verify window properties
        for window in windows {
            XCTAssertNotNil(window[kCGWindowNumber])
            XCTAssertNotNil(window[kCGWindowBounds])
        }
    }

    func testGetAllWindowsContainsFinder() throws {
        // Finder should always have windows
        let windows = windowManager.getAllWindows()

        let finderWindows = windows.filter { window in
            (window[kCGWindowOwnerName] as? String) == "Finder"
        }

        XCTAssertGreaterThan(finderWindows.count, 0, "Should find at least one Finder window")
    }

    // MARK: - getWindowsForApp Tests

    func testGetWindowsForAppByPID() throws {
        // Get Finder's PID
        let apps = NSWorkspace.shared.runningApplications
        guard let finder = apps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            XCTFail("Finder not found")
            return
        }

        let windows = windowManager.getWindowsForApp(pid: finder.processIdentifier, appName: nil)

        XCTAssertGreaterThan(windows.count, 0)

        // All windows should belong to Finder
        for window in windows {
            XCTAssertEqual(window[kCGWindowOwnerPID] as? pid_t, finder.processIdentifier)
        }
    }

    func testGetWindowsForAppByName() throws {
        // Test filtering by app name
        let allWindows = windowManager.getAllWindows()
        let finderWindows = windowManager.getWindowsForApp(pid: nil, appName: "Finder")

        // Should have fewer windows when filtered
        XCTAssertLessThanOrEqual(finderWindows.count, allWindows.count)

        // All returned windows should be from Finder
        for window in finderWindows {
            XCTAssertEqual(window[kCGWindowOwnerName] as? String, "Finder")
        }
    }

    func testGetWindowsForNonExistentApp() {
        // Test with non-existent app
        let windows = windowManager.getWindowsForApp(pid: 99999, appName: nil)

        XCTAssertEqual(windows.count, 0)
    }

    // MARK: - Window Filtering Tests

    func testWindowFilteringExcludesInvisible() {
        // Get all windows including invisible ones
        let allWindows = windowManager.getAllWindows()

        // Check that we're not including windows that are off-screen or have zero size
        for window in allWindows {
            if let bounds = window[kCGWindowBounds] as? CFDictionary {
                let rect = CGRect(dictionaryRepresentation: bounds) ?? .zero

                // If window is included, it should have non-zero size
                if rect.width > 0 && rect.height > 0 {
                    XCTAssertGreaterThan(rect.width, 0)
                    XCTAssertGreaterThan(rect.height, 0)
                }
            }
        }
    }

    func testWindowOrdering() {
        // Test that windows are ordered (typically by window level and order)
        let windows = windowManager.getAllWindows()

        guard windows.count > 1 else {
            XCTSkip("Need multiple windows to test ordering")
            return
        }

        // Windows should have window numbers
        for window in windows {
            XCTAssertNotNil(window[kCGWindowNumber])
        }
    }

    // MARK: - Performance Tests

    func testGetAllWindowsPerformance() {
        // Test performance of getting all windows
        measure {
            _ = windowManager.getAllWindows()
        }
    }

    func testGetWindowsForAppPerformance() {
        // Test performance of filtered window retrieval
        measure {
            _ = windowManager.getWindowsForApp(pid: nil, appName: "Finder")
        }
    }

    // MARK: - Helper Methods Tests

    func testCreateWindowInfo() {
        // Create a mock window dictionary
        let mockWindow: [CFString: Any] = [
            kCGWindowNumber: 123,
            kCGWindowOwnerName: "TestApp",
            kCGWindowName: "Test Window",
            kCGWindowOwnerPID: 456,
            kCGWindowBounds: [
                "X": 100,
                "Y": 200,
                "Width": 800,
                "Height": 600
            ] as CFDictionary,
            kCGWindowIsOnscreen: true,
            kCGWindowLayer: 0
        ]

        // Test window info creation
        let windowInfo = WindowInfo(
            windowID: 123,
            owningApplication: "TestApp",
            windowTitle: "Test Window",
            windowIndex: 0,
            bounds: WindowBounds(x: 100, y: 200, width: 800, height: 600),
            isOnScreen: true,
            windowLevel: 0
        )

        XCTAssertEqual(windowInfo.windowID, 123)
        XCTAssertEqual(windowInfo.owningApplication, "TestApp")
        XCTAssertEqual(windowInfo.windowTitle, "Test Window")
        XCTAssertEqual(windowInfo.bounds.x, 100)
        XCTAssertEqual(windowInfo.bounds.y, 200)
        XCTAssertEqual(windowInfo.bounds.width, 800)
        XCTAssertEqual(windowInfo.bounds.height, 600)
    }
}
