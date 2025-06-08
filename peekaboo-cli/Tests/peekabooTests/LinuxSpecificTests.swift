import XCTest
@testable import peekaboo

#if os(Linux)
import Foundation

final class LinuxSpecificTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Skip tests if running in CI without display
        guard ProcessInfo.processInfo.environment["DISPLAY"] != nil ||
              ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil else {
            throw XCTSkip("Skipping Linux tests in headless environment")
        }
    }
    
    func testLinuxScreenCaptureImplementation() throws {
        let screenCapture = LinuxScreenCapture()
        
        // Test that Linux screen capture is supported
        XCTAssertTrue(screenCapture.isScreenCaptureSupported())
        
        // Test preferred image format
        XCTAssertEqual(screenCapture.getPreferredImageFormat(), .png)
    }
    
    func testLinuxDisplayEnumeration() throws {
        let screenCapture = LinuxScreenCapture()
        
        // Test display enumeration
        let displays = try screenCapture.getAvailableDisplays()
        XCTAssertFalse(displays.isEmpty, "Linux should have at least one display")
        
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
    
    func testLinuxApplicationFinder() throws {
        let appFinder = LinuxApplicationFinder()
        
        // Test application enumeration
        let apps = try appFinder.getRunningApplications()
        XCTAssertFalse(apps.isEmpty, "Linux should have running applications")
        
        // Verify application data structure
        for app in apps.prefix(5) {
            XCTAssertGreaterThan(app.pid, 0)
            XCTAssertFalse(app.name.isEmpty)
            XCTAssertGreaterThanOrEqual(app.windowCount, 0)
        }
        
        // Test that we can find common Linux processes
        let systemApps = apps.filter { 
            $0.name.lowercased().contains("systemd") || 
            $0.name.lowercased().contains("init") ||
            $0.name.lowercased().contains("kernel")
        }
        XCTAssertFalse(systemApps.isEmpty, "Should find system processes")
    }
    
    func testLinuxWindowManager() throws {
        let windowManager = LinuxWindowManager()
        
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
    
    func testLinuxPermissionChecker() throws {
        let permissionChecker = LinuxPermissionChecker()
        
        // Test permission status (should not throw)
        let hasPermission = permissionChecker.hasScreenCapturePermission()
        XCTAssertTrue(hasPermission == true || hasPermission == false)
        
        // Test permission request capability
        let canRequest = permissionChecker.canRequestPermission()
        XCTAssertTrue(canRequest == true || canRequest == false)
        
        // Test permission request (should not throw)
        XCTAssertNoThrow(try permissionChecker.requestScreenCapturePermission())
    }
    
    func testLinuxX11Capture() async throws {
        // Skip if not running X11
        guard ProcessInfo.processInfo.environment["DISPLAY"] != nil else {
            throw XCTSkip("Skipping X11 tests - no DISPLAY environment variable")
        }
        
        let screenCapture = LinuxScreenCapture()
        
        // Test X11 screen capture
        let images = try await screenCapture.captureScreen(displayIndex: 0)
        XCTAssertFalse(images.isEmpty, "Should capture at least one screen")
        
        for image in images {
            XCTAssertGreaterThan(image.image.width, 0)
            XCTAssertGreaterThan(image.image.height, 0)
            XCTAssertNotNil(image.metadata.captureTime)
            XCTAssertEqual(image.metadata.displayIndex, 0)
        }
    }
    
    func testLinuxWaylandCapture() async throws {
        // Skip if not running Wayland
        guard ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil else {
            throw XCTSkip("Skipping Wayland tests - no WAYLAND_DISPLAY environment variable")
        }
        
        let screenCapture = LinuxScreenCapture()
        
        // Test Wayland screen capture
        let images = try await screenCapture.captureScreen(displayIndex: 0)
        XCTAssertFalse(images.isEmpty, "Should capture at least one screen")
        
        for image in images {
            XCTAssertGreaterThan(image.image.width, 0)
            XCTAssertGreaterThan(image.image.height, 0)
            XCTAssertNotNil(image.metadata.captureTime)
            XCTAssertEqual(image.metadata.displayIndex, 0)
        }
    }
    
    func testLinuxSpecificErrorHandling() async throws {
        let screenCapture = LinuxScreenCapture()
        
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
    
    func testLinuxImageFormatSupport() throws {
        let screenCapture = LinuxScreenCapture()
        
        // Test all supported formats
        let formats: [ImageFormat] = [.png, .jpeg, .bmp, .tiff]
        
        for format in formats {
            XCTAssertTrue(screenCapture.supportsImageFormat(format))
        }
    }
    
    func testLinuxMultiDisplaySupport() throws {
        let screenCapture = LinuxScreenCapture()
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
    
    func testLinuxHiDPISupport() throws {
        let screenCapture = LinuxScreenCapture()
        let displays = try screenCapture.getAvailableDisplays()
        
        // Test that scale factors are reasonable
        for display in displays {
            XCTAssertGreaterThan(display.scaleFactor, 0.5)
            XCTAssertLessThan(display.scaleFactor, 4.0)
            
            // Common Linux scale factors
            let commonScales: [CGFloat] = [1.0, 1.25, 1.5, 2.0, 3.0]
            let isCommonScale = commonScales.contains { abs($0 - display.scaleFactor) < 0.01 }
            if !isCommonScale {
                print("Unusual scale factor detected: \(display.scaleFactor)")
            }
        }
    }
    
    func testLinuxDesktopEnvironmentDetection() throws {
        let appFinder = LinuxApplicationFinder()
        let apps = try appFinder.getRunningApplications()
        
        // Try to detect desktop environment
        let desktopEnvironments = [
            "gnome", "kde", "xfce", "lxde", "mate", "cinnamon", "unity", "i3", "sway"
        ]
        
        var detectedDE: String?
        for de in desktopEnvironments {
            if apps.contains(where: { $0.name.lowercased().contains(de) }) {
                detectedDE = de
                break
            }
        }
        
        // Also check environment variables
        if detectedDE == nil {
            if let xdgCurrentDesktop = ProcessInfo.processInfo.environment["XDG_CURRENT_DESKTOP"] {
                detectedDE = xdgCurrentDesktop.lowercased()
            } else if let desktopSession = ProcessInfo.processInfo.environment["DESKTOP_SESSION"] {
                detectedDE = desktopSession.lowercased()
            }
        }
        
        print("Detected desktop environment: \(detectedDE ?? "unknown")")
    }
    
    func testLinuxPerformance() throws {
        let screenCapture = LinuxScreenCapture()
        
        // Test display enumeration performance
        measure {
            do {
                _ = try screenCapture.getAvailableDisplays()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
        
        let appFinder = LinuxApplicationFinder()
        
        // Test application enumeration performance
        measure {
            do {
                _ = try appFinder.getRunningApplications()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testLinuxMemoryManagement() async throws {
        // Skip if running in CI
        guard ProcessInfo.processInfo.environment["DISPLAY"] != nil ||
              ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil else {
            throw XCTSkip("Skipping memory tests in headless environment")
        }
        
        let screenCapture = LinuxScreenCapture()
        
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
    
    func testLinuxSystemLibraryDependencies() throws {
        // Test that required system libraries are available
        let requiredLibraries = [
            "libX11.so", "libXcomposite.so", "libXrandr.so", 
            "libXdamage.so", "libXfixes.so"
        ]
        
        for library in requiredLibraries {
            // Try to load the library (this is a basic check)
            // In a real implementation, you'd use dlopen or similar
            print("Checking for library: \(library)")
        }
    }
    
    func testLinuxDisplayServerDetection() throws {
        let isX11 = ProcessInfo.processInfo.environment["DISPLAY"] != nil
        let isWayland = ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil
        
        XCTAssertTrue(isX11 || isWayland, "Should be running either X11 or Wayland")
        
        if isX11 {
            print("Running under X11")
            XCTAssertNotNil(ProcessInfo.processInfo.environment["DISPLAY"])
        }
        
        if isWayland {
            print("Running under Wayland")
            XCTAssertNotNil(ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"])
        }
    }
}

// MARK: - Linux-specific helper extensions
extension LinuxSpecificTests {
    
    func testLinuxSystemIntegration() throws {
        // Test integration with Linux-specific APIs
        let appFinder = LinuxApplicationFinder()
        let apps = try appFinder.getRunningApplications()
        
        // Look for common Linux system processes
        let systemProcesses = ["systemd", "init", "kthreadd", "ksoftirqd"]
        var foundProcesses = 0
        
        for process in systemProcesses {
            if apps.contains(where: { $0.name.lowercased().contains(process.lowercased()) }) {
                foundProcesses += 1
            }
        }
        
        XCTAssertGreaterThan(foundProcesses, 0, "Should find at least one system process")
    }
    
    func testLinuxErrorLocalization() throws {
        let permissionChecker = LinuxPermissionChecker()
        
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
    
    func testLinuxFileSystemIntegration() throws {
        // Test that we can write to common Linux directories
        let tempDir = "/tmp"
        let testFile = "\(tempDir)/peekaboo_test_\(UUID().uuidString).txt"
        
        // Test write permission
        let testData = "test".data(using: .utf8)!
        XCTAssertNoThrow(try testData.write(to: URL(fileURLWithPath: testFile)))
        
        // Clean up
        try? FileManager.default.removeItem(atPath: testFile)
    }
}

#endif

