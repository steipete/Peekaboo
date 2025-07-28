import Testing
import AppKit
import CoreGraphics
@testable import PeekabooCore

@Suite("Focus Utilities Tests")
struct FocusUtilitiesTests {
    
    // MARK: - FocusOptions Tests
    
    @Test("FocusOptions default values")
    func focusOptionsDefaults() {
        let options = FocusOptions()
        
        #expect(options.autoFocus == true)
        #expect(options.noAutoFocus == false)
        #expect(options.focusTimeout == nil)
        #expect(options.focusRetryCount == nil)
        #expect(options.spaceSwitch == false)
        #expect(options.bringToCurrentSpace == false)
    }
    
    @Test("FocusOptions protocol conformance")
    func focusOptionsProtocolConformance() {
        var options = FocusOptions()
        options.noAutoFocus = true
        options.focusTimeout = 10.0
        options.focusRetryCount = 5
        options.spaceSwitch = true
        options.bringToCurrentSpace = true
        
        // Test as protocol
        let protocolOptions: FocusOptionsProtocol = options
        #expect(protocolOptions.autoFocus == false) // inverted from noAutoFocus
        #expect(protocolOptions.focusTimeout == 10.0)
        #expect(protocolOptions.focusRetryCount == 5)
        #expect(protocolOptions.spaceSwitch == true)
        #expect(protocolOptions.bringToCurrentSpace == true)
    }
    
    @Test("DefaultFocusOptions values")
    func defaultFocusOptionsValues() {
        let options = DefaultFocusOptions()
        
        #expect(options.autoFocus == true)
        #expect(options.focusTimeout == 5.0)
        #expect(options.focusRetryCount == 3)
        #expect(options.spaceSwitch == true)
        #expect(options.bringToCurrentSpace == false)
    }
    
    // MARK: - FocusManagementService Tests
    
    @Test("FocusManagementService initialization")
    @MainActor
    func focusServiceInit() {
        let _ = FocusManagementService()
        // Should initialize without crashing
        // Service is non-optional, so it will always be created
    }
    
    @Test("FocusOptions struct initialization")
    func focusServiceOptionsInit() {
        let options = FocusManagementService.FocusOptions()
        
        #expect(options.timeout == 5.0)
        #expect(options.retryCount == 3)
        #expect(options.switchSpace == true)
        #expect(options.bringToCurrentSpace == false)
        
        let customOptions = FocusManagementService.FocusOptions(
            timeout: 10.0,
            retryCount: 5,
            switchSpace: false,
            bringToCurrentSpace: true
        )
        
        #expect(customOptions.timeout == 10.0)
        #expect(customOptions.retryCount == 5)
        #expect(customOptions.switchSpace == false)
        #expect(customOptions.bringToCurrentSpace == true)
    }
    
    @Test("findBestWindow with non-existent app")
    @MainActor
    func findBestWindowNonExistent() async throws {
        let service = FocusManagementService()
        
        do {
            _ = try await service.findBestWindow(
                applicationName: "NonExistentApp12345",
                windowTitle: nil
            )
            Issue.record("Expected to throw for non-existent app")
        } catch {
            // Expected to fail
            #expect(error is FocusError)
        }
    }
    
    @Test("findBestWindow with Finder")
    @MainActor
    func findBestWindowFinder() async throws {
        let service = FocusManagementService()
        
        // Finder should always be running
        do {
            let windowID = try await service.findBestWindow(
                applicationName: "Finder",
                windowTitle: nil
            )
            
            if let id = windowID {
                #expect(id > 0)
            }
            // It's OK if Finder has no windows
        } catch {
            // Should not fail for Finder
            Issue.record("Unexpected error: \(error)")
        }
    }
    
    // MARK: - FocusError Tests
    
    @Test("FocusError descriptions")
    func focusErrorDescriptions() {
        let errors: [FocusError] = [
            .applicationNotRunning("TestApp"),
            .noWindowsFound("TestApp"),
            .windowNotFound(12345),
            .axElementNotFound(12345),
            .focusVerificationFailed(12345),
            .focusVerificationTimeout(12345),
            .timeoutWaitingForCondition
        ]
        
        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(!description!.isEmpty)
        }
    }
}

// MARK: - Mock Tests for Session Integration

@Suite("Focus Session Integration Tests")
struct FocusSessionIntegrationTests {
    
    @Test("Session stores window ID")
    func sessionWindowID() {
        var session = UIAutomationSession(
            version: UIAutomationSession.currentVersion,
            applicationName: "TestApp",
            windowTitle: "Test Window"
        )
        
        #expect(session.windowID == nil)
        
        // Set window ID
        session.windowID = 12345
        #expect(session.windowID == 12345)
        
        // Set AX identifier
        session.windowAXIdentifier = "test-window-id"
        #expect(session.windowAXIdentifier == "test-window-id")
        
        // Set focus time
        let now = Date()
        session.lastFocusTime = now
        #expect(session.lastFocusTime == now)
    }
    
    @Test("Session encoding with window info")
    func sessionEncodingWithWindow() throws {
        let session = UIAutomationSession(
            version: UIAutomationSession.currentVersion,
            applicationName: "TestApp",
            windowTitle: "Test Window",
            windowBounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            windowID: 99999,
            windowAXIdentifier: "window-ax-id",
            lastFocusTime: Date()
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(session)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UIAutomationSession.self, from: data)
        
        #expect(decoded.windowID == 99999)
        #expect(decoded.windowAXIdentifier == "window-ax-id")
        #expect(decoded.lastFocusTime != nil)
    }
}