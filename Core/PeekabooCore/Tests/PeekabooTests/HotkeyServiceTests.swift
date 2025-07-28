import Testing
@testable import PeekabooCore
import Foundation
import CoreGraphics

@Suite("HotkeyService Tests", .tags(.ui))
@MainActor
struct HotkeyServiceTests {
    
    @Test("Initialize HotkeyService")
    func initializeService() async throws {
        let service = HotkeyService()
        #expect(service != nil)
    }
    
    @Test("Press single modifier hotkeys")
    func singleModifierHotkeys() async throws {
        let service = HotkeyService()
        
        // Test common single-modifier hotkeys
        try await service.pressHotkey(key: .a, modifiers: [.command])  // Cmd+A
        try await service.pressHotkey(key: .c, modifiers: [.command])  // Cmd+C
        try await service.pressHotkey(key: .v, modifiers: [.command])  // Cmd+V
        try await service.pressHotkey(key: .z, modifiers: [.command])  // Cmd+Z
        try await service.pressHotkey(key: .s, modifiers: [.command])  // Cmd+S
        
        try await service.pressHotkey(key: .a, modifiers: [.control])  // Ctrl+A
        try await service.pressHotkey(key: .tab, modifiers: [.option]) // Option+Tab
    }
    
    @Test("Press multiple modifier hotkeys")
    func multipleModifierHotkeys() async throws {
        let service = HotkeyService()
        
        // Test multiple modifier combinations
        try await service.pressHotkey(key: .z, modifiers: [.command, .shift])      // Cmd+Shift+Z (Redo)
        try await service.pressHotkey(key: .s, modifiers: [.command, .option])     // Cmd+Option+S
        try await service.pressHotkey(key: .i, modifiers: [.command, .option])     // Cmd+Option+I (Dev Tools)
        try await service.pressHotkey(key: .f, modifiers: [.control, .command])    // Ctrl+Cmd+F (Fullscreen)
        
        // Test triple modifier
        try await service.pressHotkey(key: .delete, modifiers: [.command, .option, .shift])
    }
    
    @Test("Press function keys")
    func functionKeys() async throws {
        let service = HotkeyService()
        
        // Test function keys
        try await service.pressHotkey(key: .f1, modifiers: [])
        try await service.pressHotkey(key: .f2, modifiers: [])
        try await service.pressHotkey(key: .f3, modifiers: [])
        try await service.pressHotkey(key: .f12, modifiers: [])
        
        // Function keys with modifiers
        try await service.pressHotkey(key: .f11, modifiers: [.command])  // Show Desktop
        try await service.pressHotkey(key: .f3, modifiers: [.control])   // Mission Control
    }
    
    @Test("Press navigation keys")
    func navigationKeys() async throws {
        let service = HotkeyService()
        
        // Test arrow keys with modifiers
        try await service.pressHotkey(key: .rightArrow, modifiers: [.command])  // End of line
        try await service.pressHotkey(key: .leftArrow, modifiers: [.command])   // Beginning of line
        try await service.pressHotkey(key: .upArrow, modifiers: [.command])     // Top of document
        try await service.pressHotkey(key: .downArrow, modifiers: [.command])   // Bottom of document
        
        // Word navigation
        try await service.pressHotkey(key: .rightArrow, modifiers: [.option])
        try await service.pressHotkey(key: .leftArrow, modifiers: [.option])
    }
    
    @Test("Press special keys")
    func specialKeys() async throws {
        let service = HotkeyService()
        
        // Test special keys
        try await service.pressHotkey(key: .return, modifiers: [])
        try await service.pressHotkey(key: .space, modifiers: [])
        try await service.pressHotkey(key: .tab, modifiers: [])
        try await service.pressHotkey(key: .escape, modifiers: [])
        try await service.pressHotkey(key: .delete, modifiers: [])
        try await service.pressHotkey(key: .forwardDelete, modifiers: [])
        
        // Special keys with modifiers
        try await service.pressHotkey(key: .return, modifiers: [.command])      // Send (in messaging apps)
        try await service.pressHotkey(key: .space, modifiers: [.command])       // Spotlight
        try await service.pressHotkey(key: .tab, modifiers: [.command])         // App switcher
    }
    
    @Test("Common application hotkeys")
    func commonAppHotkeys() async throws {
        let service = HotkeyService()
        
        // Test common application hotkeys
        try await service.pressHotkey(key: .n, modifiers: [.command])           // New
        try await service.pressHotkey(key: .o, modifiers: [.command])           // Open
        try await service.pressHotkey(key: .w, modifiers: [.command])           // Close
        try await service.pressHotkey(key: .q, modifiers: [.command])           // Quit
        try await service.pressHotkey(key: .f, modifiers: [.command])           // Find
        try await service.pressHotkey(key: .g, modifiers: [.command])           // Find Next
        try await service.pressHotkey(key: .comma, modifiers: [.command])       // Preferences
        try await service.pressHotkey(key: .slash, modifiers: [.command])       // Help
    }
    
    @Test("System hotkeys")
    func systemHotkeys() async throws {
        let service = HotkeyService()
        
        // Test system-level hotkeys (be careful with these in tests)
        try await service.pressHotkey(key: .h, modifiers: [.command])           // Hide
        try await service.pressHotkey(key: .m, modifiers: [.command])           // Minimize
        try await service.pressHotkey(key: .space, modifiers: [.control])       // Switch input source
    }
    
    @Test("Empty modifiers")
    func noModifiers() async throws {
        let service = HotkeyService()
        
        // Test keys without any modifiers
        try await service.pressHotkey(key: .a, modifiers: [])
        try await service.pressHotkey(key: .space, modifiers: [])
        try await service.pressHotkey(key: .return, modifiers: [])
    }
    
    @Test("All modifiers")
    func allModifiers() async throws {
        let service = HotkeyService()
        
        // Test with all modifiers
        try await service.pressHotkey(
            key: .a,
            modifiers: [.command, .option, .control, .shift]
        )
    }
}