import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCore

@Suite(
    "HotkeyService Tests",
    .tags(.ui, .automation),
    .enabled(if: TestEnvironment.runInputAutomationScenarios))
@MainActor
struct HotkeyServiceTests {
    @Test("Initialize HotkeyService")
    func initializeService() async throws {
        let service: HotkeyService? = HotkeyService()
        #expect(service != nil)
    }

    @Test("Press single modifier hotkeys")
    func singleModifierHotkeys() async throws {
        let service = HotkeyService()

        // Test common single-modifier hotkeys
        try await service.hotkey(keys: "cmd,a", holdDuration: 100) // Cmd,A
        try await service.hotkey(keys: "cmd,c", holdDuration: 100) // Cmd,C
        try await service.hotkey(keys: "cmd,v", holdDuration: 100) // Cmd,V
        try await service.hotkey(keys: "cmd,z", holdDuration: 100) // Cmd,Z
        try await service.hotkey(keys: "cmd,s", holdDuration: 100) // Cmd,S

        try await service.hotkey(keys: "ctrl,a", holdDuration: 100) // Ctrl,A
        try await service.hotkey(keys: "opt,tab", holdDuration: 100) // Option,Tab
    }

    @Test("Press multiple modifier hotkeys")
    func multipleModifierHotkeys() async throws {
        let service = HotkeyService()

        // Test multiple modifier combinations
        try await service.hotkey(keys: "cmd,shift,z", holdDuration: 100) // Cmd,Shift,Z (Redo)
        try await service.hotkey(keys: "cmd,opt,s", holdDuration: 100) // Cmd,Option,S
        try await service.hotkey(keys: "cmd,opt,i", holdDuration: 100) // Cmd,Option,I (Dev Tools)
        try await service.hotkey(keys: "ctrl,cmd,f", holdDuration: 100) // Ctrl,Cmd,F (Fullscreen)

        // Test triple modifier
        try await service.hotkey(keys: "cmd,opt,shift,delete", holdDuration: 100)
    }

    @Test("Press function keys")
    func functionKeys() async throws {
        let service = HotkeyService()

        // Test function keys
        try await service.hotkey(keys: "f1", holdDuration: 100)
        try await service.hotkey(keys: "f2", holdDuration: 100)
        try await service.hotkey(keys: "f3", holdDuration: 100)
        try await service.hotkey(keys: "f12", holdDuration: 100)

        // Function keys with modifiers
        try await service.hotkey(keys: "cmd,f11", holdDuration: 100) // Show Desktop
        try await service.hotkey(keys: "ctrl,f3", holdDuration: 100) // Mission Control
    }

    @Test("Press navigation keys")
    func navigationKeys() async throws {
        let service = HotkeyService()

        // Test arrow keys with modifiers
        try await service.hotkey(keys: "cmd,right", holdDuration: 100) // End of line
        try await service.hotkey(keys: "cmd,left", holdDuration: 100) // Beginning of line
        try await service.hotkey(keys: "cmd,up", holdDuration: 100) // Top of document
        try await service.hotkey(keys: "cmd,down", holdDuration: 100) // Bottom of document

        // Word navigation
        try await service.hotkey(keys: "opt,right", holdDuration: 100)
        try await service.hotkey(keys: "opt,left", holdDuration: 100)
    }

    @Test("Press special keys")
    func specialKeys() async throws {
        let service = HotkeyService()

        // Test special keys
        try await service.hotkey(keys: "return", holdDuration: 100)
        try await service.hotkey(keys: "space", holdDuration: 100)
        try await service.hotkey(keys: "tab", holdDuration: 100)
        try await service.hotkey(keys: "escape", holdDuration: 100)
        try await service.hotkey(keys: "delete", holdDuration: 100)

        // Special keys with modifiers
        try await service.hotkey(keys: "cmd,return", holdDuration: 100) // Send (in messaging apps)
        try await service.hotkey(keys: "cmd,space", holdDuration: 100) // Spotlight
        try await service.hotkey(keys: "cmd,tab", holdDuration: 100) // App switcher
    }

    @Test("Common application hotkeys")
    func commonAppHotkeys() async throws {
        let service = HotkeyService()

        // Test common application hotkeys
        try await service.hotkey(keys: "cmd,n", holdDuration: 100) // New
        try await service.hotkey(keys: "cmd,o", holdDuration: 100) // Open
        try await service.hotkey(keys: "cmd,w", holdDuration: 100) // Close
        try await service.hotkey(keys: "cmd,q", holdDuration: 100) // Quit
        try await service.hotkey(keys: "cmd,f", holdDuration: 100) // Find
        try await service.hotkey(keys: "cmd,g", holdDuration: 100) // Find Next
        try await service.hotkey(keys: "cmd,comma", holdDuration: 100) // Preferences
        try await service.hotkey(keys: "cmd,slash", holdDuration: 100) // Help
    }

    @Test("System hotkeys")
    func systemHotkeys() async throws {
        let service = HotkeyService()

        // Test system-level hotkeys (be careful with these in tests)
        try await service.hotkey(keys: "cmd,h", holdDuration: 100) // Hide
        try await service.hotkey(keys: "cmd,m", holdDuration: 100) // Minimize
        try await service.hotkey(keys: "ctrl,space", holdDuration: 100) // Switch input source
    }

    @Test("Fast key press")
    func fastKeyPress() async throws {
        let service = HotkeyService()

        // Test with minimal hold duration
        try await service.hotkey(keys: "cmd,a", holdDuration: 10)
    }

    @Test("Long key hold")
    func longKeyHold() async throws {
        let service = HotkeyService()

        // Test with longer hold duration
        try await service.hotkey(keys: "cmd,a", holdDuration: 500)
    }

    @Test("All modifiers")
    func allModifiers() async throws {
        let service = HotkeyService()

        // Test with all modifiers
        try await service.hotkey(
            keys: "cmd,opt,ctrl,shift,a",
            holdDuration: 100)
    }

    @Test("Alternative modifier names")
    func alternativeModifierNames() async throws {
        let service = HotkeyService()

        // Test alternative modifier names
        try await service.hotkey(keys: "command,a", holdDuration: 100)
        try await service.hotkey(keys: "option,b", holdDuration: 100)
        try await service.hotkey(keys: "control,c", holdDuration: 100)
        try await service.hotkey(keys: "alt,d", holdDuration: 100)
    }
}
