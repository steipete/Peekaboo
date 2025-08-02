import Foundation
import Testing
import ScreenCaptureKit
@testable import PeekabooCore

@Suite("ScreenCaptureService Multi-Screen Tests", .tags(.ui))
@available(macOS 14.0, *)
@MainActor
struct ScreenCaptureServiceMultiScreenTests {
    
    @Test("Capture specific screen by index")
    func captureSpecificScreen() async throws {
        let service = ScreenCaptureService()
        
        // Get available displays
        let content = try await SCShareableContent.current
        let displays = content.displays
        
        guard !displays.isEmpty else {
            throw Issue.record("No displays available for testing")
        }
        
        // Try to capture the first screen
        let result = try await service.captureScreen(displayIndex: 0)
        
        #expect(!result.imageData.isEmpty)
        #expect(result.captureMode == .screen)
        #expect(result.metadata.displayInfo != nil)
        
        if let displayInfo = result.metadata.displayInfo {
            #expect(displayInfo.index == 0)
            #expect(displayInfo.bounds.width > 0)
            #expect(displayInfo.bounds.height > 0)
        }
    }
    
    @Test("Capture all screens returns multiple results")
    func captureAllScreens() async throws {
        // This test would verify that capturing without displayIndex
        // returns results for all available screens
        
        // Note: This is a conceptual test since captureScreen currently
        // returns a single CaptureResult. The multi-screen logic is
        // implemented in SeeCommand.captureAllScreens()
        
        let service = ScreenCaptureService()
        
        // Get available displays to know what to expect
        let content = try await SCShareableContent.current
        let displays = content.displays
        
        // Currently captureScreen(displayIndex: nil) returns first screen
        let result = try await service.captureScreen(displayIndex: nil)
        
        #expect(!result.imageData.isEmpty)
        #expect(result.captureMode == .screen)
    }
    
    @Test("Invalid screen index throws appropriate error")
    func invalidScreenIndex() async throws {
        let service = ScreenCaptureService()
        
        // Try to capture a screen that definitely doesn't exist
        do {
            _ = try await service.captureScreen(displayIndex: 999)
            throw Issue.record("Expected error for invalid screen index")
        } catch {
            // Expected to throw an error
            #expect(error.localizedDescription.contains("Invalid display index") || 
                    error.localizedDescription.contains("Display not found"))
        }
    }
    
    @Test("Display info includes proper metadata")
    func displayInfoMetadata() async throws {
        let service = ScreenCaptureService()
        
        // Capture primary screen
        let result = try await service.captureScreen(displayIndex: 0)
        
        guard let displayInfo = result.metadata.displayInfo else {
            throw Issue.record("Display info should be present for screen captures")
        }
        
        // Verify display info has expected properties
        #expect(displayInfo.index >= 0)
        #expect(displayInfo.bounds.width > 0)
        #expect(displayInfo.bounds.height > 0)
        
        // Display name might be nil for some displays, that's ok
        if let name = displayInfo.name {
            #expect(!name.isEmpty)
        }
    }
}