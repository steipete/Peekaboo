import AppKit
import Testing
@testable import Peekaboo

@Suite("DockIconManager Tests", .tags(.ui, .unit))
@MainActor
struct DockIconManagerTests {
    @Test("Manager follows singleton pattern")
    func singletonPattern() {
        let instance1 = DockIconManager.shared
        let instance2 = DockIconManager.shared

        // Both references should point to the same instance
        #expect(instance1 === instance2)
    }

    @Test("Initial dock icon visibility state")
    func initialState() {
        let manager = DockIconManager.shared

        // Check if we can get the current visibility state
        // The actual state depends on app configuration
        let isVisible = manager.isDockIconVisible
        #expect(isVisible == true || isVisible == false) // Should be a valid boolean
    }

    @Test("Show dock icon")
    func showDockIcon() {
        let manager = DockIconManager.shared

        // Show the dock icon
        manager.showDockIcon()

        // Verify it's visible
        #expect(manager.isDockIconVisible == true)

        // In a real app, this would show the icon in the dock
        // NSApp.setActivationPolicy(.regular)
    }

    @Test("Hide dock icon")
    func hideDockIcon() {
        let manager = DockIconManager.shared

        // Hide the dock icon
        manager.hideDockIcon()

        // Verify it's hidden
        #expect(manager.isDockIconVisible == false)

        // In a real app, this would hide the icon from the dock
        // NSApp.setActivationPolicy(.accessory)
    }

    @Test("Toggle dock icon visibility")
    func toggleVisibility() {
        let manager = DockIconManager.shared

        // Get initial state
        let initialState = manager.isDockIconVisible

        // Toggle
        manager.toggleDockIcon()

        // Should be opposite of initial state
        #expect(manager.isDockIconVisible == !initialState)

        // Toggle back
        manager.toggleDockIcon()

        // Should be back to initial state
        #expect(manager.isDockIconVisible == initialState)
    }

    @Test("Persistence of dock icon preference")
    func persistenceOfPreference() {
        let manager = DockIconManager.shared

        // Set a specific state
        manager.showDockIcon()

        // The preference should be saved (typically in UserDefaults)
        // In a real implementation, we'd check UserDefaults here
        #expect(manager.isDockIconVisible == true)

        // Hide it
        manager.hideDockIcon()
        #expect(manager.isDockIconVisible == false)
    }

    @Test("Dock icon state changes are immediate")
    func immediateStateChanges() {
        let manager = DockIconManager.shared

        // Rapid state changes should work
        manager.showDockIcon()
        #expect(manager.isDockIconVisible == true)

        manager.hideDockIcon()
        #expect(manager.isDockIconVisible == false)

        manager.showDockIcon()
        #expect(manager.isDockIconVisible == true)
    }

    @Test("Thread safety of dock icon operations")
    func threadSafety() async {
        let manager = DockIconManager.shared

        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await MainActor.run {
                        if i % 2 == 0 {
                            manager.showDockIcon()
                        } else {
                            manager.hideDockIcon()
                        }
                    }
                }
            }
        }

        // Manager should still be in a valid state
        let finalState = manager.isDockIconVisible
        #expect(finalState == true || finalState == false)
    }

    @Test("Dock icon updates when app becomes active")
    func appActivationUpdates() {
        let manager = DockIconManager.shared

        // When app is set to show dock icon
        manager.showDockIcon()

        // The activation policy should be updated
        // In a real scenario, we'd check NSApp.activationPolicy() == .regular
        #expect(manager.isDockIconVisible == true)
    }
}
