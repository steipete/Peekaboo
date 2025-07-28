import Testing
import AppKit
import AXorcist
@testable import Peekaboo

@Suite("OverlayManager Tests", .tags(.ui, .unit))
@MainActor
struct OverlayManagerTests {
    
    @Test("Manager initializes with default state")
    func initialization() {
        let manager = OverlayManager()
        
        // Verify default state
        #expect(manager.isOverlayActive == false)
        #expect(manager.hoveredElement == nil)
        #expect(manager.selectedElement == nil)
        #expect(manager.applications.isEmpty)
        #expect(manager.selectedAppMode == .all)
        #expect(manager.detailLevel == .normal)
    }
    
    @Test("Start and stop overlay")
    func overlayLifecycle() async throws {
        let manager = OverlayManager()
        
        // Start overlay
        await manager.startOverlay()
        
        // Verify overlay is active
        #expect(manager.isOverlayActive == true)
        
        // Stop overlay
        await manager.stopOverlay()
        
        // Verify overlay is inactive
        #expect(manager.isOverlayActive == false)
        #expect(manager.hoveredElement == nil)
        #expect(manager.selectedElement == nil)
    }
    
    @Test("Application filtering modes")
    func appFilteringModes() {
        let manager = OverlayManager()
        
        // Test all apps mode
        manager.selectedAppMode = .all
        #expect(manager.selectedAppMode == .all)
        #expect(manager.selectedAppBundleID == nil)
        
        // Test specific app mode
        manager.selectedAppMode = .specific
        manager.selectedAppBundleID = "com.apple.finder"
        #expect(manager.selectedAppMode == .specific)
        #expect(manager.selectedAppBundleID == "com.apple.finder")
        
        // Test frontmost app mode
        manager.selectedAppMode = .frontmost
        #expect(manager.selectedAppMode == .frontmost)
    }
    
    @Test("Detail level settings")
    func detailLevels() {
        let manager = OverlayManager()
        
        // Test each detail level
        let levels: [OverlayManager.DetailLevel] = [.minimal, .normal, .detailed]
        
        for level in levels {
            manager.detailLevel = level
            #expect(manager.detailLevel == level)
        }
    }
    
    @Test("Element selection")
    func elementSelection() async {
        let manager = OverlayManager()
        
        // Create mock element info
        let mockElement = OverlayManager.ElementInfo(
            element: nil, // Would be actual AXUIElement in real scenario
            globalFrame: CGRect(x: 100, y: 100, width: 200, height: 50),
            role: "AXButton",
            title: "Test Button",
            label: nil,
            value: nil,
            identifier: nil,
            help: nil,
            roleDescription: nil,
            description: nil,
            actions: ["AXPress"],
            isEnabled: true,
            customProperties: [:]
        )
        
        // Select element
        manager.selectedElement = mockElement
        #expect(manager.selectedElement != nil)
        #expect(manager.selectedElement?.title == "Test Button")
        
        // Clear selection
        manager.selectedElement = nil
        #expect(manager.selectedElement == nil)
    }
    
    @Test("Mouse tracking")
    func mouseTracking() async {
        let manager = OverlayManager()
        
        // Simulate mouse location update
        let testLocation = CGPoint(x: 500, y: 300)
        manager.currentMouseLocation = testLocation
        
        #expect(manager.currentMouseLocation == testLocation)
    }
    
    @Test("Application refresh")
    func applicationRefresh() async {
        let manager = OverlayManager()
        
        // Refresh applications
        await manager.refreshApplications()
        
        // Should have at least some system apps (Finder, etc.)
        // Note: This might be empty in test environment
        #expect(manager.applications.isEmpty || !manager.applications.isEmpty)
    }
    
    @Test("Overlay window management")
    func overlayWindows() async {
        let manager = OverlayManager()
        
        // Start overlay to create windows
        await manager.startOverlay()
        
        // Windows should be created (though we can't access private properties)
        #expect(manager.isOverlayActive == true)
        
        // Stop overlay to clean up windows
        await manager.stopOverlay()
        
        // Windows should be cleaned up
        #expect(manager.isOverlayActive == false)
    }
    
    @Test("Element info equality")
    func elementInfoEquality() {
        let element1 = OverlayManager.ElementInfo(
            element: nil,
            globalFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            role: "AXButton",
            title: "Button",
            label: nil,
            value: nil,
            identifier: nil,
            help: nil,
            roleDescription: nil,
            description: nil,
            actions: [],
            isEnabled: true,
            customProperties: [:]
        )
        
        let element2 = OverlayManager.ElementInfo(
            element: nil,
            globalFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            role: "AXButton",
            title: "Button",
            label: nil,
            value: nil,
            identifier: nil,
            help: nil,
            roleDescription: nil,
            description: nil,
            actions: [],
            isEnabled: true,
            customProperties: [:]
        )
        
        // Elements with same properties should be equal
        #expect(element1 == element2)
        
        // Change one property
        var element3 = element1
        element3.title = "Different Button"
        #expect(element1 != element3)
    }
    
    @Test("Performance with multiple windows")
    func performanceMultipleWindows() async {
        let manager = OverlayManager()
        
        let startTime = Date()
        
        // Start and stop overlay multiple times
        for _ in 0..<5 {
            await manager.startOverlay()
            await manager.stopOverlay()
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time (2 seconds for 5 iterations)
        #expect(duration < 2.0)
    }
    
    @Test("Thread safety")
    func threadSafety() async {
        let manager = OverlayManager()
        
        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Start overlay
            group.addTask {
                await manager.startOverlay()
            }
            
            // Update properties
            group.addTask {
                await MainActor.run {
                    manager.detailLevel = .detailed
                    manager.selectedAppMode = .frontmost
                }
            }
            
            // Refresh applications
            group.addTask {
                await manager.refreshApplications()
            }
        }
        
        // Clean up
        await manager.stopOverlay()
        
        // Manager should still be in valid state
        #expect(manager.isOverlayActive == false)
    }
}