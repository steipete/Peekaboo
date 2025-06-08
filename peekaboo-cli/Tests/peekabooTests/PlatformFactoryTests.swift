import XCTest
@testable import peekaboo

final class PlatformFactoryTests: XCTestCase {
    
    func testPlatformDetection() {
        // Test that we can detect the current platform
        let platform = PlatformFactory.currentPlatform
        XCTAssertFalse(platform.isEmpty, "Platform should be detected")
        
        #if os(macOS)
        XCTAssertEqual(platform, "macOS")
        #elseif os(Windows)
        XCTAssertEqual(platform, "Windows")
        #elseif os(Linux)
        XCTAssertEqual(platform, "Linux")
        #endif
    }
    
    func testPlatformSupport() {
        // Test that the current platform is supported
        XCTAssertTrue(PlatformFactory.isSupported, "Current platform should be supported")
    }
    
    func testCapabilities() {
        // Test that we can get platform capabilities
        let capabilities = PlatformFactory.capabilities
        
        // All platforms should support at least some functionality
        XCTAssertTrue(
            capabilities.screenCapture ||
            capabilities.windowManagement ||
            capabilities.applicationFinding ||
            capabilities.permissions,
            "Platform should support at least one capability"
        )
    }
    
    func testScreenCaptureCreation() {
        // Test that we can create a screen capture implementation
        let screenCapture = PlatformFactory.createScreenCapture()
        XCTAssertNotNil(screenCapture, "Should be able to create screen capture implementation")
        
        // Test that the implementation reports correct support
        let isSupported = type(of: screenCapture).isSupported()
        XCTAssertTrue(isSupported, "Screen capture should be supported on current platform")
    }
    
    func testWindowManagerCreation() {
        // Test that we can create a window manager implementation
        let windowManager = PlatformFactory.createWindowManager()
        XCTAssertNotNil(windowManager, "Should be able to create window manager implementation")
        
        // Test that the implementation reports correct support
        let isSupported = type(of: windowManager).isSupported()
        XCTAssertTrue(isSupported, "Window management should be supported on current platform")
    }
    
    func testApplicationFinderCreation() {
        // Test that we can create an application finder implementation
        let applicationFinder = PlatformFactory.createApplicationFinder()
        XCTAssertNotNil(applicationFinder, "Should be able to create application finder implementation")
        
        // Test that the implementation reports correct support
        let isSupported = type(of: applicationFinder).isSupported()
        XCTAssertTrue(isSupported, "Application finding should be supported on current platform")
    }
    
    func testPermissionsCheckerCreation() {
        // Test that we can create a permissions checker implementation
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        XCTAssertNotNil(permissionsChecker, "Should be able to create permissions checker implementation")
        
        // Test that the implementation reports correct support
        let isSupported = type(of: permissionsChecker).isSupported()
        XCTAssertTrue(isSupported, "Permissions checking should be supported on current platform")
    }
    
    func testPlatformSpecificImplementations() {
        #if os(macOS)
        testMacOSImplementations()
        #elseif os(Windows)
        testWindowsImplementations()
        #elseif os(Linux)
        testLinuxImplementations()
        #endif
    }
    
    #if os(macOS)
    private func testMacOSImplementations() {
        let screenCapture = PlatformFactory.createScreenCapture()
        XCTAssertTrue(screenCapture is macOSScreenCapture, "Should create macOS screen capture implementation")
        
        let windowManager = PlatformFactory.createWindowManager()
        XCTAssertTrue(windowManager is macOSWindowManager, "Should create macOS window manager implementation")
        
        let applicationFinder = PlatformFactory.createApplicationFinder()
        XCTAssertTrue(applicationFinder is macOSApplicationFinder, "Should create macOS application finder implementation")
        
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        XCTAssertTrue(permissionsChecker is macOSPermissions, "Should create macOS permissions checker implementation")
    }
    #endif
    
    #if os(Windows)
    private func testWindowsImplementations() {
        let screenCapture = PlatformFactory.createScreenCapture()
        XCTAssertTrue(screenCapture is WindowsScreenCapture, "Should create Windows screen capture implementation")
        
        let windowManager = PlatformFactory.createWindowManager()
        XCTAssertTrue(windowManager is WindowsWindowManager, "Should create Windows window manager implementation")
        
        let applicationFinder = PlatformFactory.createApplicationFinder()
        XCTAssertTrue(applicationFinder is WindowsApplicationFinder, "Should create Windows application finder implementation")
        
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        XCTAssertTrue(permissionsChecker is WindowsPermissions, "Should create Windows permissions checker implementation")
    }
    #endif
    
    #if os(Linux)
    private func testLinuxImplementations() {
        let screenCapture = PlatformFactory.createScreenCapture()
        XCTAssertTrue(screenCapture is LinuxScreenCapture, "Should create Linux screen capture implementation")
        
        let windowManager = PlatformFactory.createWindowManager()
        XCTAssertTrue(windowManager is LinuxWindowManager, "Should create Linux window manager implementation")
        
        let applicationFinder = PlatformFactory.createApplicationFinder()
        XCTAssertTrue(applicationFinder is LinuxApplicationFinder, "Should create Linux application finder implementation")
        
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        XCTAssertTrue(permissionsChecker is LinuxPermissions, "Should create Linux permissions checker implementation")
    }
    #endif
    
    func testCapabilitiesStructure() {
        let capabilities = PlatformFactory.capabilities
        
        // Test that capabilities structure is properly formed
        XCTAssertNotNil(capabilities, "Capabilities should not be nil")
        
        // Test that isFullySupported works correctly
        let expectedFullSupport = capabilities.screenCapture && 
                                 capabilities.windowManagement && 
                                 capabilities.applicationFinding && 
                                 capabilities.permissions
        XCTAssertEqual(capabilities.isFullySupported, expectedFullSupport, "isFullySupported should match individual capabilities")
    }
}

