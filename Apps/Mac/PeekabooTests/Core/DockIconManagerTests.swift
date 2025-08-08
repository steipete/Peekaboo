import AppKit
import Testing
@testable import Peekaboo

@Suite("DockIconManager Tests", .tags(.ui, .unit))
@MainActor
struct DockIconManagerTests {
    var manager: DockIconManager!
    var settings: PeekabooSettings!

    @Test("Dock icon is shown by default when setting is true")
    mutating func dockIconShownByDefault() async {
        await setup()
        settings.showInDock = true
        manager.updateDockVisibility()
        #expect(NSApp.activationPolicy() == .regular)
    }

    @Test("Dock icon is hidden by default when setting is false")
    mutating func dockIconHiddenByDefault() async {
        await setup()
        settings.showInDock = false
        manager.updateDockVisibility()
        #expect(NSApp.activationPolicy() == .accessory)
    }

    @Test("Dock icon is shown when a window is visible, regardless of setting")
    mutating func dockIconShownWithVisibleWindow() async {
        await setup()
        settings.showInDock = false
        manager.updateDockVisibility()
        #expect(NSApp.activationPolicy() == .accessory, "Precondition: Dock icon should be hidden")

        // Simulate opening a window
        let window = NSWindow(contentRect: .zero, styleMask: .titled, backing: .buffered, defer: false)
        window.makeKeyAndOrderFront(nil)
        
        manager.updateDockVisibility()
        
        #expect(NSApp.activationPolicy() == .regular, "Dock icon should be visible when a window is open")
        
        window.close()
        manager.updateDockVisibility()
        #expect(NSApp.activationPolicy() == .accessory, "Dock icon should hide again after window is closed")
    }
    
    @Test("Temporarily showing dock works")
    mutating func temporarilyShowDock() async {
        await setup()
        settings.showInDock = false
        manager.updateDockVisibility()
        #expect(NSApp.activationPolicy() == .accessory, "Precondition: Dock icon should be hidden")
        
        manager.temporarilyShowDock()
        #expect(NSApp.activationPolicy() == .regular, "Dock icon should be temporarily visible")
    }

    private mutating func setup() async {
        _ = NSApplication.shared
        manager = DockIconManager.shared
        // Use a temporary, non-shared settings instance for testing
        settings = PeekabooSettings()
        manager.connectToSettings(settings)
    }
}