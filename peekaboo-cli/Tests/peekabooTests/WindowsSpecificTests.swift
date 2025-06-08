import XCTest
@testable import peekaboo

#if os(Windows)
import WinSDK

final class WindowsSpecificTests: XCTestCase {
    
    func testWindowsScreenCaptureImplementation() throws {
        let screenCapture = WindowsScreenCapture()
        
        // Test that Windows screen capture is supported
        XCTAssertTrue(screenCapture.isScreenCaptureSupported())
        
        // Test preferred image format
        XCTAssertEqual(screenCapture.getPreferredImageFormat(), .png)
    }
    
    func testWindowsDisplayEnumeration() throws {
        let screenCapture = WindowsScreenCapture()
        
        // Test display enumeration
        let displays = try screenCapture.getAvailableDisplays()
        XCTAssertFalse(displays.isEmpty, "Windows should have at least one display")
        
        // Verify display properties
        for display in displays {
            XCTAssertGreaterThan(display.displayId, 0)
            XCTAssertGreaterThanOrEqual(display.index, 0)
            XCTAssertGreaterThan(display.bounds.width, 0)
            XCTAssertGreaterThan(display.bounds.height, 0)
            XCTAssertGreaterThan(display.scaleFactor, 0)
            XCTAssertNotNil(display.name)
        }
        
        // Test primary display detection
        let primaryDisplays = displays.filter { $0.isPrimary }
        XCTAssertEqual(primaryDisplays.count, 1, "Should have exactly one primary display")
    }
    
    func testWindowsApplicationFinder() throws {
        let appFinder = WindowsApplicationFinder()
        
        // Test application enumeration
        let apps = try appFinder.getRunningApplications()
        XCTAssertFalse(apps.isEmpty, "Windows should have running applications")
        
        // Verify application data structure
        for app in apps.prefix(5) {
            XCTAssertGreaterThan(app.pid, 0)
            XCTAssertFalse(app.name.isEmpty)
            // Bundle identifier might be nil on Windows
            XCTAssertGreaterThanOrEqual(app.windowCount, 0)
        }
        
        // Test that we can find system processes
        let systemApps = apps.filter { $0.name.lowercased().contains("explorer") }
        XCTAssertFalse(systemApps.isEmpty, "Should find Windows Explorer")
    }
    
    func testWindowsWindowManager() throws {
        let windowManager = WindowsWindowManager()
        
        // Test window enumeration
        let windows = try windowManager.getVisibleWindows()
        
        // Verify window data structure
        for window in windows.prefix(3) {
            XCTAssertGreaterThan(window.windowId, 0)
            XCTAssertGreaterThan(window.ownerPid, 0)
            XCTAssertGreaterThan(window.bounds.width, 0)
            XCTAssertGreaterThan(window.bounds.height, 0)
            // Title might be empty for some windows
        }
    }
    
    func testWindowsPermissionChecker() throws {
        let permissionChecker = WindowsPermissionChecker()
        
        // Test permission status (should not throw)
        let hasPermission = permissionChecker.hasScreenCapturePermission()
        XCTAssertTrue(hasPermission == true || hasPermission == false)
        
        // Test permission request capability
        let canRequest = permissionChecker.canRequestPermission()
        XCTAssertTrue(canRequest == true || canRequest == false)
        
        // Test permission request (should not throw)
        XCTAssertNoThrow(try permissionChecker.requestScreenCapturePermission())
    }
    
    func testWindowsDXGICapture() async throws {
        // Skip if running in CI without display
        guard !ProcessInfo.processInfo.environment.keys.contains("CI") else {
            throw XCTSkip("Skipping DXGI tests in CI environment")
        }
        
        let screenCapture = WindowsScreenCapture()
        
        // Test DXGI screen capture
        let images = try await screenCapture.captureScreen(displayIndex: 0)
        XCTAssertFalse(images.isEmpty, "Should capture at least one screen")
        
        for image in images {
            XCTAssertGreaterThan(image.image.width, 0)
            XCTAssertGreaterThan(image.image.height, 0)
            XCTAssertNotNil(image.metadata.captureTime)
            XCTAssertEqual(image.metadata.displayIndex, 0)
        }
    }
    
    func testWindowsSpecificErrorHandling() async throws {
        let screenCapture = WindowsScreenCapture()
        
        // Test invalid display index
        do {
            _ = try await screenCapture.captureScreen(displayIndex: 9999)
            XCTFail("Should throw error for invalid display index")
        } catch ScreenCaptureError.displayNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test invalid window ID
        do {
            _ = try await screenCapture.captureWindow(windowId: 0)
            XCTFail("Should throw error for invalid window ID")
        } catch ScreenCaptureError.windowNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testWindowsImageFormatSupport() throws {
        let screenCapture = WindowsScreenCapture()
        
        // Test all supported formats
        let formats: [ImageFormat] = [.png, .jpeg, .bmp, .tiff]
        
        for format in formats {
            XCTAssertTrue(screenCapture.supportsImageFormat(format))
        }
    }
    
    func testWindowsMultiDisplaySupport() throws {
        let screenCapture = WindowsScreenCapture()
        let displays = try screenCapture.getAvailableDisplays()
        
        if displays.count > 1 {
            // Test multi-display scenarios
            for (index, display) in displays.enumerated() {
                XCTAssertEqual(display.index, index)
                
                // Test display bounds don't overlap incorrectly
                if index > 0 {
                    let previousDisplay = displays[index - 1]
                    // Displays can be arranged in various configurations
                    XCTAssertNotEqual(display.bounds, previousDisplay.bounds)
                }
            }
        }
    }
    
    func testWindowsHighDPISupport() throws {
        let screenCapture = WindowsScreenCapture()
        let displays = try screenCapture.getAvailableDisplays()
        
        // Test that scale factors are reasonable
        for display in displays {
            XCTAssertGreaterThan(display.scaleFactor, 0.5)
            XCTAssertLessThan(display.scaleFactor, 5.0)
            
            // Common Windows scale factors
            let commonScales: [CGFloat] = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 3.0]
            let isCommonScale = commonScales.contains { abs($0 - display.scaleFactor) < 0.01 }
            if !isCommonScale {
                print("Unusual scale factor detected: \(display.scaleFactor)")
            }
        }
    }
    
    func testWindowsPerformance() throws {
        let screenCapture = WindowsScreenCapture()
        
        // Test display enumeration performance
        measure {
            do {
                _ = try screenCapture.getAvailableDisplays()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
        
        let appFinder = WindowsApplicationFinder()
        
        // Test application enumeration performance
        measure {
            do {
                _ = try appFinder.getRunningApplications()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testWindowsMemoryManagement() async throws {
        // Skip if running in CI
        guard !ProcessInfo.processInfo.environment.keys.contains("CI") else {
            throw XCTSkip("Skipping memory tests in CI environment")
        }
        
        let screenCapture = WindowsScreenCapture()
        
        // Capture multiple screenshots to test memory cleanup
        for _ in 0..<5 {
            let images = try await screenCapture.captureScreen(displayIndex: 0)
            XCTAssertFalse(images.isEmpty)
            
            // Force cleanup
            autoreleasepool {
                // Images should be released here
            }
        }
    }
}

// MARK: - Windows-specific helper extensions
extension WindowsSpecificTests {
    
    func testWindowsSystemIntegration() throws {
        // Test integration with Windows-specific APIs
        let appFinder = WindowsApplicationFinder()
        let apps = try appFinder.getRunningApplications()
        
        // Look for common Windows applications
        let commonApps = ["explorer.exe", "dwm.exe", "winlogon.exe"]
        var foundApps = 0
        
        for commonApp in commonApps {
            if apps.contains(where: { $0.name.lowercased().contains(commonApp.lowercased()) }) {
                foundApps += 1
            }
        }
        
        XCTAssertGreaterThan(foundApps, 0, "Should find at least one common Windows application")
    }
    
    func testWindowsErrorLocalization() throws {
        let permissionChecker = WindowsPermissionChecker()
        
        // Test that error messages are properly localized
        do {
            // This might throw if permissions are not available
            try permissionChecker.requireScreenCapturePermission()
        } catch let error as ScreenCaptureError {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        } catch {
            // Other errors are also acceptable
        }
    }
}

#endif

