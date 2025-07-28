import Testing
@testable import PeekabooCore
import Foundation
import CoreGraphics

@Suite("TypeService Tests", .tags(.ui))
struct TypeServiceTests {
    
    @Test("Initialize TypeService")
    func initializeService() async throws {
        let service = await TypeService()
        #expect(service != nil)
    }
    
    @Test("Type text")
    func typeBasicText() async throws {
        let service = await TypeService()
        
        // Test basic text typing
        try await service.type(
            text: "Hello World",
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Type with special characters")
    func typeSpecialCharacters() async throws {
        let service = await TypeService()
        
        // Test typing with special characters
        let specialText = "Hello! @#$% 123 🎉"
        try await service.type(
            text: specialText,
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Type in specific element")
    func typeInElement() async throws {
        let service = await TypeService()
        
        // Test typing in a specific element (by query)
        // In test environment, this will attempt to find an element
        // but may not succeed - we're testing the API
        do {
            try await service.type(
                text: "test@example.com",
                target: .query("email"),
                sessionId: nil
            )
        } catch is NotFoundError {
            // Expected in test environment
        }
    }
    
    @Test("Clear and type")
    func clearAndType() async throws {
        let service = await TypeService()
        
        // Test clearing before typing
        try await service.clearAndType(
            text: "New text",
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Press key")
    func pressSpecialKey() async throws {
        let service = await TypeService()
        
        // Test pressing special keys
        try await service.pressKey(.return)
        try await service.pressKey(.tab)
        try await service.pressKey(.escape)
        try await service.pressKey(.delete)
    }
    
    @Test("Key combinations")
    func keyCombinations() async throws {
        let service = await TypeService()
        
        // Test various key combinations
        try await service.pressKey(.a, modifiers: [.command])  // Cmd+A
        try await service.pressKey(.c, modifiers: [.command])  // Cmd+C
        try await service.pressKey(.v, modifiers: [.command])  // Cmd+V
        try await service.pressKey(.z, modifiers: [.command, .shift])  // Cmd+Shift+Z
    }
    
    @Test("Type with delays")
    func typeWithDelays() async throws {
        let service = await TypeService()
        
        // Test typing with character delay
        let startTime = Date()
        try await service.type(
            text: "Slow",
            target: nil,
            sessionId: nil,
            characterDelay: 100  // 100ms between characters
        )
        let duration = Date().timeIntervalSince(startTime)
        
        // Should take at least 300ms for 4 characters (3 delays)
        #expect(duration >= 0.3)
    }
    
    @Test("Empty text handling")
    func typeEmptyText() async throws {
        let service = await TypeService()
        
        // Should handle empty text gracefully
        try await service.type(
            text: "",
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Unicode text")
    func typeUnicodeText() async throws {
        let service = await TypeService()
        
        // Test various Unicode characters
        let unicodeTexts = [
            "こんにちは",  // Japanese
            "你好",        // Chinese  
            "مرحبا",       // Arabic
            "🌍🌎🌏",      // Emojis
            "café",        // Accented characters
            "™®©",         // Symbols
        ]
        
        for text in unicodeTexts {
            try await service.type(
                text: text,
                target: nil,
                sessionId: nil
            )
        }
    }
}