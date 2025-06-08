import Testing
@testable import peekaboo

@Suite("Platform Factory Tests")
struct PlatformFactoryTests {
    
    @Test("Platform detection works correctly")
    func testPlatformDetection() {
        // Test that we can detect the current platform
        let platform = PlatformFactory.currentPlatform
        #expect(!platform.isEmpty, "Platform should be detected")
        
        #if os(macOS)
        #expect(platform == "macOS")
        #elseif os(Windows)
        #expect(platform == "Windows")
        #elseif os(Linux)
        #expect(platform == "Linux")
        #endif
    }
    
    @Test("Platform support is correctly reported")
    func testPlatformSupport() {
        // Test that the current platform is supported
        #expect(PlatformFactory.isSupported, "Current platform should be supported")
    }
    
    @Test("Platform capabilities are available")
    func testCapabilities() {
        // Test that we can get platform capabilities
        let capabilities = PlatformFactory.capabilities
        
        // All platforms should support at least some functionality
        #expect(
            capabilities.screenCapture ||
            capabilities.windowManagement ||
            capabilities.applicationFinding ||
            capabilities.permissions,
            "Platform should support at least one capability"
        )
    }
    
    @Test("Screen capture implementation can be created")
    func testScreenCaptureCreation() {
        // Test that we can create a screen capture implementation
        let screenCapture = PlatformFactory.createScreenCapture()
        #expect(screenCapture != nil, "Should be able to create screen capture implementation")
        
        // Test that the implementation reports correct support
        let isSupported = type(of: screenCapture).isSupported()
        #expect(isSupported, "Screen capture should be supported on current platform")
    }
    
    @Test("Window manager implementation can be created")
    func testWindowManagerCreation() {
        // Test that we can create a window manager implementation
        let windowManager = PlatformFactory.createWindowManager()
        #expect(windowManager != nil, "Should be able to create window manager implementation")
        
        // Note: Window management support varies by platform
        // macOS: fully supported
        // Linux/Windows: placeholder implementations for now
    }
    
    @Test("Application finder implementation can be created")
    func testApplicationFinderCreation() {
        // Test that we can create an application finder implementation
        let applicationFinder = PlatformFactory.createApplicationFinder()
        #expect(applicationFinder != nil, "Should be able to create application finder implementation")
        
        // Test that the implementation reports correct support
        let isSupported = type(of: applicationFinder).isSupported()
        #expect(isSupported, "Application finding should be supported on current platform")
    }
    
    @Test("Permissions checker implementation can be created")
    func testPermissionsCheckerCreation() {
        // Test that we can create a permissions checker implementation
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        #expect(permissionsChecker != nil, "Should be able to create permissions checker implementation")
        
        // Test that the implementation reports correct support
        let isSupported = type(of: permissionsChecker).isSupported()
        #expect(isSupported, "Permissions checking should be supported on current platform")
    }
    
    @Test("Platform-specific implementations are correct")
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
        #expect(screenCapture is macOSScreenCapture, "Should create macOS screen capture implementation")
        
        let windowManager = PlatformFactory.createWindowManager()
        #expect(windowManager is macOSWindowManager, "Should create macOS window manager implementation")
        
        let applicationFinder = PlatformFactory.createApplicationFinder()
        #expect(applicationFinder is macOSApplicationFinder, "Should create macOS application finder implementation")
        
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        #expect(permissionsChecker is macOSPermissions, "Should create macOS permissions checker implementation")
    }
    #endif
    
    #if os(Windows)
    private func testWindowsImplementations() {
        let screenCapture = PlatformFactory.createScreenCapture()
        #expect(screenCapture is WindowsScreenCapture, "Should create Windows screen capture implementation")
        
        let windowManager = PlatformFactory.createWindowManager()
        #expect(windowManager is WindowsWindowManager, "Should create Windows window manager implementation")
        
        let applicationFinder = PlatformFactory.createApplicationFinder()
        #expect(applicationFinder is WindowsApplicationFinder, "Should create Windows application finder implementation")
        
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        #expect(permissionsChecker is WindowsPermissions, "Should create Windows permissions checker implementation")
    }
    #endif
    
    #if os(Linux)
    private func testLinuxImplementations() {
        let screenCapture = PlatformFactory.createScreenCapture()
        #expect(screenCapture is LinuxScreenCapture, "Should create Linux screen capture implementation")
        
        let windowManager = PlatformFactory.createWindowManager()
        #expect(windowManager is LinuxWindowManager, "Should create Linux window manager implementation")
        
        let applicationFinder = PlatformFactory.createApplicationFinder()
        #expect(applicationFinder is LinuxApplicationFinder, "Should create Linux application finder implementation")
        
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        #expect(permissionsChecker is LinuxPermissions, "Should create Linux permissions checker implementation")
    }
    #endif
    
    @Test("Capabilities structure is properly formed")
    func testCapabilitiesStructure() {
        let capabilities = PlatformFactory.capabilities
        
        // Test that capabilities structure is properly formed
        #expect(capabilities != nil, "Capabilities should not be nil")
        
        // Test that isFullySupported works correctly
        let expectedFullSupport = capabilities.screenCapture && 
                                 capabilities.windowManagement && 
                                 capabilities.applicationFinding && 
                                 capabilities.permissions
        #expect(capabilities.isFullySupported == expectedFullSupport, "isFullySupported should match individual capabilities")
    }
    
    @Test("Cross-platform window manager protocol compatibility")
    func testWindowManagerProtocolCompatibility() async throws {
        let windowManager = PlatformFactory.createWindowManager()
        
        // Test that the protocol methods can be called without compilation errors
        let allWindows = try await windowManager.getAllWindows()
        #expect(allWindows != nil, "getAllWindows should return a non-nil array")
        
        // Test getting windows for a non-existent application
        let appWindows = try await windowManager.getWindows(for: "non-existent-app")
        #expect(appWindows.isEmpty, "Should return empty array for non-existent application")
        
        // Test getting a specific window
        let specificWindow = try await windowManager.getWindow(by: "non-existent-window")
        #expect(specificWindow == nil, "Should return nil for non-existent window")
    }
}

