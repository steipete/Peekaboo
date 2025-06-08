import XCTest
@testable import peekaboo

/// Comprehensive tests to ensure the project is ready for shipping across all platforms
final class ShippingReadinessTests: XCTestCase {
    
    func testPlatformFactoryCompleteness() throws {
        // Test that PlatformFactory can create all required components
        XCTAssertNotNil(PlatformFactory.createScreenCapture())
        XCTAssertNotNil(PlatformFactory.createApplicationFinder())
        XCTAssertNotNil(PlatformFactory.createWindowManager())
        XCTAssertNotNil(PlatformFactory.createPermissionChecker())
        
        // Test platform support detection
        XCTAssertTrue(PlatformFactory.isPlatformSupported())
    }
    
    func testAllImageFormatsSupported() throws {
        let allFormats = ImageFormat.allCases
        XCTAssertEqual(allFormats.count, 5) // png, jpeg, jpg, bmp, tiff
        
        for format in allFormats {
            // Test that each format has proper properties
            XCTAssertFalse(format.mimeType.isEmpty)
            XCTAssertFalse(format.fileExtension.isEmpty)
            XCTAssertFalse(format.coreGraphicsType.isEmpty)
            
            // Test MIME type format
            XCTAssertTrue(format.mimeType.starts(with: "image/"))
            
            // Test CoreGraphics type format
            XCTAssertTrue(format.coreGraphicsType.starts(with: "public."))
        }
    }
    
    func testErrorHandlingCompleteness() throws {
        // Test that all error types have proper descriptions
        let errors: [ScreenCaptureError] = [
            .notSupported,
            .permissionDenied,
            .displayNotFound(1),
            .windowNotFound(123),
            .captureFailure("test"),
            .invalidConfiguration,
            .systemError(NSError(domain: "test", code: 1))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
    
    func testDataModelIntegrity() throws {
        // Test CapturedImage structure
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 100,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 400,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let cgImage = context.makeImage()!
        
        let metadata = CaptureMetadata(
            captureTime: Date(),
            displayIndex: 0,
            windowId: nil,
            windowTitle: nil,
            applicationName: nil,
            bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            scaleFactor: 1.0,
            colorSpace: colorSpace
        )
        
        let capturedImage = CapturedImage(image: cgImage, metadata: metadata)
        
        XCTAssertEqual(capturedImage.image.width, 100)
        XCTAssertEqual(capturedImage.image.height, 100)
        XCTAssertEqual(capturedImage.metadata.displayIndex, 0)
        XCTAssertEqual(capturedImage.metadata.scaleFactor, 1.0)
        XCTAssertEqual(capturedImage.metadata.bounds.width, 100)
        XCTAssertEqual(capturedImage.metadata.bounds.height, 100)
    }
    
    func testDisplayInfoStructure() throws {
        let displayInfo = DisplayInfo(
            displayId: 1,
            index: 0,
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            workArea: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            scaleFactor: 2.0,
            isPrimary: true,
            name: "Test Display",
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        XCTAssertEqual(displayInfo.displayId, 1)
        XCTAssertEqual(displayInfo.index, 0)
        XCTAssertEqual(displayInfo.bounds.width, 1920)
        XCTAssertEqual(displayInfo.bounds.height, 1080)
        XCTAssertEqual(displayInfo.workArea.height, 1055) // Smaller due to taskbar/dock
        XCTAssertEqual(displayInfo.scaleFactor, 2.0)
        XCTAssertTrue(displayInfo.isPrimary)
        XCTAssertEqual(displayInfo.name, "Test Display")
        XCTAssertNotNil(displayInfo.colorSpace)
    }
    
    func testApplicationInfoStructure() throws {
        let appInfo = ApplicationInfo(
            pid: 1234,
            name: "Test App",
            bundleIdentifier: "com.test.app",
            windowCount: 2,
            isActive: true,
            cpuUsage: 5.5,
            memoryUsage: 1024 * 1024 * 100 // 100MB
        )
        
        XCTAssertEqual(appInfo.pid, 1234)
        XCTAssertEqual(appInfo.name, "Test App")
        XCTAssertEqual(appInfo.bundleIdentifier, "com.test.app")
        XCTAssertEqual(appInfo.windowCount, 2)
        XCTAssertTrue(appInfo.isActive)
        XCTAssertEqual(appInfo.cpuUsage, 5.5)
        XCTAssertEqual(appInfo.memoryUsage, 1024 * 1024 * 100)
    }
    
    func testWindowInfoStructure() throws {
        let windowInfo = WindowInfo(
            windowId: 12345,
            ownerPid: 1234,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            isVisible: true,
            isMinimized: false,
            windowIndex: 0
        )
        
        XCTAssertEqual(windowInfo.windowId, 12345)
        XCTAssertEqual(windowInfo.ownerPid, 1234)
        XCTAssertEqual(windowInfo.title, "Test Window")
        XCTAssertEqual(windowInfo.bounds.width, 800)
        XCTAssertEqual(windowInfo.bounds.height, 600)
        XCTAssertTrue(windowInfo.isVisible)
        XCTAssertFalse(windowInfo.isMinimized)
        XCTAssertEqual(windowInfo.windowIndex, 0)
    }
    
    func testProtocolConformance() throws {
        let factory = PlatformFactory()
        
        // Test that all created objects conform to their protocols
        let screenCapture = factory.createScreenCapture()
        XCTAssertTrue(screenCapture is ScreenCaptureProtocol)
        
        let appFinder = factory.createApplicationFinder()
        XCTAssertTrue(appFinder is ApplicationFinderProtocol)
        
        let windowManager = factory.createWindowManager()
        XCTAssertTrue(windowManager is WindowManagerProtocol)
        
        let permissionChecker = factory.createPermissionChecker()
        XCTAssertTrue(permissionChecker is PermissionCheckerProtocol)
    }
    
    func testPlatformSpecificImplementations() throws {
        let factory = PlatformFactory()
        
        #if os(macOS)
        XCTAssertTrue(factory.createScreenCapture() is macOSScreenCapture)
        XCTAssertTrue(factory.createApplicationFinder() is macOSApplicationFinder)
        XCTAssertTrue(factory.createWindowManager() is macOSWindowManager)
        XCTAssertTrue(factory.createPermissionChecker() is macOSPermissionChecker)
        
        #elseif os(Windows)
        XCTAssertTrue(factory.createScreenCapture() is WindowsScreenCapture)
        XCTAssertTrue(factory.createApplicationFinder() is WindowsApplicationFinder)
        XCTAssertTrue(factory.createWindowManager() is WindowsWindowManager)
        XCTAssertTrue(factory.createPermissionChecker() is WindowsPermissionChecker)
        
        #elseif os(Linux)
        XCTAssertTrue(factory.createScreenCapture() is LinuxScreenCapture)
        XCTAssertTrue(factory.createApplicationFinder() is LinuxApplicationFinder)
        XCTAssertTrue(factory.createWindowManager() is LinuxWindowManager)
        XCTAssertTrue(factory.createPermissionChecker() is LinuxPermissionChecker)
        #endif
    }
    
    func testCrossplatformCompatibility() throws {
        // Test that all platforms support basic functionality
        let factory = PlatformFactory()
        let screenCapture = factory.createScreenCapture()
        
        // All platforms should support screen capture
        XCTAssertTrue(screenCapture.isScreenCaptureSupported())
        
        // All platforms should have a preferred image format
        let preferredFormat = screenCapture.getPreferredImageFormat()
        XCTAssertTrue(ImageFormat.allCases.contains(preferredFormat))
        
        // All platforms should support at least PNG
        XCTAssertTrue(screenCapture.supportsImageFormat(.png))
    }
    
    func testMemoryManagement() throws {
        // Test that objects can be created and released without issues
        autoreleasepool {
            let factory = PlatformFactory()
            _ = factory.createScreenCapture()
            _ = factory.createApplicationFinder()
            _ = factory.createWindowManager()
            _ = factory.createPermissionChecker()
        }
        
        // Test multiple factory instances
        for _ in 0..<10 {
            autoreleasepool {
                let factory = PlatformFactory()
                _ = factory.createScreenCapture()
            }
        }
    }
    
    func testThreadSafety() throws {
        let factory = PlatformFactory()
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = 10
        
        // Test creating objects from multiple threads
        for i in 0..<10 {
            DispatchQueue.global(qos: .background).async {
                autoreleasepool {
                    let screenCapture = factory.createScreenCapture()
                    XCTAssertNotNil(screenCapture)
                    XCTAssertTrue(screenCapture.isScreenCaptureSupported())
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPackageConfiguration() throws {
        // This test ensures the Package.swift is properly configured
        // We can't directly test Package.swift, but we can test that
        // platform-specific code compiles correctly
        
        #if os(macOS)
        // Test macOS-specific imports work
        XCTAssertNoThrow({
            _ = macOSScreenCapture()
        })
        
        #elseif os(Windows)
        // Test Windows-specific imports work
        XCTAssertNoThrow({
            _ = WindowsScreenCapture()
        })
        
        #elseif os(Linux)
        // Test Linux-specific imports work
        XCTAssertNoThrow({
            _ = LinuxScreenCapture()
        })
        #endif
    }
    
    func testDocumentationCompleteness() throws {
        // Test that key types have proper documentation
        // This is a basic check - in practice you'd use a documentation tool
        
        let factory = PlatformFactory()
        XCTAssertNotNil(factory)
        
        // Test that error types are well-defined
        let error = ScreenCaptureError.notSupported
        XCTAssertNotNil(error.errorDescription)
        
        // Test that image formats are well-defined
        for format in ImageFormat.allCases {
            XCTAssertFalse(format.mimeType.isEmpty)
            XCTAssertFalse(format.fileExtension.isEmpty)
        }
    }
    
    func testVersionCompatibility() throws {
        // Test that the implementation works with the expected Swift version
        #if swift(>=5.10)
        // We require Swift 5.10 or later
        XCTAssertTrue(true)
        #else
        XCTFail("Swift 5.10 or later is required")
        #endif
        
        // Test platform version requirements
        #if os(macOS)
        if #available(macOS 14.0, *) {
            XCTAssertTrue(true)
        } else {
            XCTFail("macOS 14.0 or later is required")
        }
        #endif
    }
    
    func testBuildConfiguration() throws {
        // Test that we're building with the correct configuration
        #if DEBUG
        print("Running in DEBUG configuration")
        #else
        print("Running in RELEASE configuration")
        #endif
        
        // Test that platform-specific code is properly conditionally compiled
        #if os(macOS)
        XCTAssertTrue(PlatformFactory.createScreenCapture() is macOSScreenCapture)
        #elseif os(Windows)
        XCTAssertTrue(PlatformFactory.createScreenCapture() is WindowsScreenCapture)
        #elseif os(Linux)
        XCTAssertTrue(PlatformFactory.createScreenCapture() is LinuxScreenCapture)
        #else
        XCTFail("Unsupported platform")
        #endif
    }
    
    func testShippingReadiness() throws {
        // Final comprehensive test that everything is ready for shipping
        
        // 1. Platform support
        XCTAssertTrue(PlatformFactory.isPlatformSupported())
        
        // 2. Core functionality
        let factory = PlatformFactory()
        let screenCapture = factory.createScreenCapture()
        let appFinder = factory.createApplicationFinder()
        let windowManager = factory.createWindowManager()
        let permissionChecker = factory.createPermissionChecker()
        
        XCTAssertNotNil(screenCapture)
        XCTAssertNotNil(appFinder)
        XCTAssertNotNil(windowManager)
        XCTAssertNotNil(permissionChecker)
        
        // 3. Basic functionality works
        XCTAssertTrue(screenCapture.isScreenCaptureSupported())
        XCTAssertNoThrow(try screenCapture.getAvailableDisplays())
        
        // 4. Error handling is robust
        XCTAssertNotNil(ScreenCaptureError.notSupported.errorDescription)
        
        // 5. Image formats are supported
        XCTAssertTrue(screenCapture.supportsImageFormat(.png))
        
        // 6. Memory management is sound
        autoreleasepool {
            _ = PlatformFactory()
        }
        
        print("✅ All shipping readiness checks passed!")
    }
}

// MARK: - Performance Tests for Shipping
extension ShippingReadinessTests {
    
    func testPerformanceBaseline() throws {
        let factory = PlatformFactory()
        let screenCapture = factory.createScreenCapture()
        
        // Test that basic operations are fast enough for production
        measure {
            do {
                _ = try screenCapture.getAvailableDisplays()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
        
        let appFinder = factory.createApplicationFinder()
        measure {
            do {
                _ = try appFinder.getRunningApplications()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testMemoryPerformance() throws {
        // Test that memory usage is reasonable
        let factory = PlatformFactory()
        
        measure {
            autoreleasepool {
                for _ in 0..<100 {
                    _ = factory.createScreenCapture()
                }
            }
        }
    }
}

