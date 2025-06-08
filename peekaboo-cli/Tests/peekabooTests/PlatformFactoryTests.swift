import XCTest
@testable import peekaboo

final class PlatformFactoryTests: XCTestCase {
    
    func testPlatformDetection() {
        // Test that platform detection works
        let platform = PlatformFactory.currentPlatform
        XCTAssertNotEqual(platform, .unsupported, "Platform should be supported")
        
        #if os(macOS)
        XCTAssertEqual(platform, .macOS, "Should detect macOS")
        #elseif os(Windows)
        XCTAssertEqual(platform, .windows, "Should detect Windows")
        #elseif os(Linux)
        XCTAssertEqual(platform, .linux, "Should detect Linux")
        #endif
    }
    
    func testPlatformSupport() {
        // Test that platform is supported
        XCTAssertTrue(PlatformFactory.isPlatformSupported(), "Platform should be supported")
    }
    
    func testPlatformInfo() {
        // Test that platform info is available
        let info = PlatformFactory.getPlatformInfo()
        XCTAssertNotEqual(info.platform, .unsupported)
        XCTAssertNotEqual(info.architecture, .unknown)
        XCTAssertFalse(info.version.isEmpty)
    }
    
    func testFactoryCreation() {
        // Test that factory can create implementations
        XCTAssertNoThrow(try {
            let screenCapture = PlatformFactory.createScreenCapture()
            XCTAssertTrue(screenCapture.isScreenCaptureSupported())
            
            let windowManager = PlatformFactory.createWindowManager()
            XCTAssertTrue(windowManager.isWindowManagementSupported())
            
            let applicationFinder = PlatformFactory.createApplicationFinder()
            XCTAssertTrue(applicationFinder.isApplicationManagementSupported())
            
            let permissionsManager = PlatformFactory.createPermissionsManager()
            // Permissions manager should always be created successfully
        }())
    }
    
    func testPlatformCapabilities() {
        // Test platform capabilities
        let info = PlatformFactory.getPlatformInfo()
        let capabilities = info.capabilities
        
        // All supported platforms should have basic capabilities
        XCTAssertTrue(capabilities.screenCapture, "Screen capture should be supported")
        XCTAssertTrue(capabilities.windowManagement, "Window management should be supported")
        XCTAssertTrue(capabilities.applicationManagement, "Application management should be supported")
    }
    
    #if os(macOS)
    func testMacOSSpecificFeatures() {
        // Test macOS-specific features
        let info = PlatformFactory.getPlatformInfo()
        XCTAssertTrue(info.capabilities.permissionManagement, "macOS should require permission management")
        XCTAssertTrue(info.capabilities.highDPI, "macOS should support high DPI")
    }
    #endif
    
    #if os(Windows)
    func testWindowsSpecificFeatures() {
        // Test Windows-specific features
        let info = PlatformFactory.getPlatformInfo()
        XCTAssertFalse(info.capabilities.permissionManagement, "Windows should not require explicit screen recording permission")
        XCTAssertTrue(info.capabilities.multiDisplay, "Windows should support multiple displays")
    }
    #endif
    
    #if os(Linux)
    func testLinuxSpecificFeatures() {
        // Test Linux-specific features
        let info = PlatformFactory.getPlatformInfo()
        XCTAssertTrue(info.capabilities.multiDisplay, "Linux should support multiple displays")
        // Permission management depends on desktop environment
    }
    #endif
}

