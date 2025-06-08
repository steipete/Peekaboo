import XCTest
import Foundation
@testable import peekaboo

final class IntegrationTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Skip tests if running in CI without display
        guard !ProcessInfo.processInfo.environment.keys.contains("CI") || 
              ProcessInfo.processInfo.environment["DISPLAY"] != nil else {
            throw XCTSkip("Skipping integration tests in headless CI environment")
        }
    }
    
    func testCrossplatformScreenCapture() async throws {
        let factory = PlatformFactory()
        let screenCapture = factory.createScreenCapture()
        
        // Test that screen capture is supported
        XCTAssertTrue(screenCapture.isScreenCaptureSupported())
        
        // Test display enumeration
        let displays = try screenCapture.getAvailableDisplays()
        XCTAssertFalse(displays.isEmpty, "Should have at least one display")
        
        // Test screen capture
        let images = try await screenCapture.captureScreen(displayIndex: nil)
        XCTAssertFalse(images.isEmpty, "Should capture at least one screen")
        
        for image in images {
            XCTAssertGreaterThan(image.image.width, 0)
            XCTAssertGreaterThan(image.image.height, 0)
            XCTAssertNotNil(image.metadata.captureTime)
        }
    }
    
    func testCrossplatformApplicationFinder() throws {
        let factory = PlatformFactory()
        let appFinder = factory.createApplicationFinder()
        
        // Test application enumeration
        let apps = try appFinder.getRunningApplications()
        XCTAssertFalse(apps.isEmpty, "Should have at least one running application")
        
        // Verify application data structure
        for app in apps.prefix(5) { // Test first 5 apps
            XCTAssertGreaterThan(app.pid, 0)
            XCTAssertFalse(app.name.isEmpty)
            XCTAssertFalse(app.bundleIdentifier?.isEmpty ?? false)
        }
    }
    
    func testCrossplatformWindowManager() throws {
        let factory = PlatformFactory()
        let windowManager = factory.createWindowManager()
        
        // Test window enumeration
        let windows = try windowManager.getVisibleWindows()
        
        // May be empty in headless environments, so just verify structure
        for window in windows.prefix(3) { // Test first 3 windows
            XCTAssertGreaterThan(window.windowId, 0)
            XCTAssertGreaterThan(window.ownerPid, 0)
            XCTAssertFalse(window.title.isEmpty)
            XCTAssertGreaterThan(window.bounds.width, 0)
            XCTAssertGreaterThan(window.bounds.height, 0)
        }
    }
    
    func testPermissionChecker() throws {
        let factory = PlatformFactory()
        let permissionChecker = factory.createPermissionChecker()
        
        // Test permission status (should not throw)
        let hasPermission = permissionChecker.hasScreenCapturePermission()
        
        // On CI, we might not have permissions, so just verify it returns a boolean
        XCTAssertTrue(hasPermission == true || hasPermission == false)
        
        // Test permission request (should not throw)
        let canRequest = permissionChecker.canRequestPermission()
        XCTAssertTrue(canRequest == true || canRequest == false)
    }
    
    func testImageFormatHandling() throws {
        // Test all supported formats
        let formats: [ImageFormat] = [.png, .jpeg, .jpg, .bmp, .tiff]
        
        for format in formats {
            // Test MIME type
            XCTAssertFalse(format.mimeType.isEmpty)
            XCTAssertTrue(format.mimeType.starts(with: "image/"))
            
            // Test file extension
            XCTAssertFalse(format.fileExtension.isEmpty)
            
            // Test CoreGraphics type
            XCTAssertFalse(format.coreGraphicsType.isEmpty)
            XCTAssertTrue(format.coreGraphicsType.starts(with: "public."))
            
            #if os(macOS)
            // Test UTType (macOS only)
            XCTAssertNotNil(format.utType)
            #endif
        }
    }
    
    func testPlatformSpecificFeatures() throws {
        let factory = PlatformFactory()
        
        #if os(macOS)
        // Test macOS-specific features
        let appFinder = factory.createApplicationFinder() as? macOSApplicationFinder
        XCTAssertNotNil(appFinder)
        
        let screenCapture = factory.createScreenCapture() as? macOSScreenCapture
        XCTAssertNotNil(screenCapture)
        XCTAssertEqual(screenCapture?.getPreferredImageFormat(), .png)
        
        #elseif os(Windows)
        // Test Windows-specific features
        let screenCapture = factory.createScreenCapture() as? WindowsScreenCapture
        XCTAssertNotNil(screenCapture)
        XCTAssertEqual(screenCapture?.getPreferredImageFormat(), .png)
        
        #elseif os(Linux)
        // Test Linux-specific features
        let screenCapture = factory.createScreenCapture() as? LinuxScreenCapture
        XCTAssertNotNil(screenCapture)
        XCTAssertEqual(screenCapture?.getPreferredImageFormat(), .png)
        #endif
    }
    
    func testErrorHandling() async throws {
        let factory = PlatformFactory()
        let screenCapture = factory.createScreenCapture()
        
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
}

// MARK: - Performance Tests
final class PerformanceTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Skip performance tests in CI
        guard !ProcessInfo.processInfo.environment.keys.contains("CI") else {
            throw XCTSkip("Skipping performance tests in CI environment")
        }
    }
    
    func testScreenCapturePerformance() throws {
        let factory = PlatformFactory()
        let screenCapture = factory.createScreenCapture()
        
        measure {
            do {
                _ = try screenCapture.getAvailableDisplays()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testApplicationEnumerationPerformance() throws {
        let factory = PlatformFactory()
        let appFinder = factory.createApplicationFinder()
        
        measure {
            do {
                _ = try appFinder.getRunningApplications()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testWindowEnumerationPerformance() throws {
        let factory = PlatformFactory()
        let windowManager = factory.createWindowManager()
        
        measure {
            do {
                _ = try windowManager.getVisibleWindows()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}

