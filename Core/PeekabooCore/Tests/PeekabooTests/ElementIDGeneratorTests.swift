import Testing
import Foundation
@testable import PeekabooCore

@Suite("ElementIDGenerator Tests")
@MainActor
struct ElementIDGeneratorTests {
    
    let generator = ElementIDGenerator()
    
    // MARK: - ID Generation Tests
    
    @Test("Generate IDs for different categories")
    @MainActor
    func generateIDsForCategories() {
        // Reset to start fresh
        generator.resetCounters()
        
        // Generate IDs for different categories
        let buttonID1 = generator.generateID(for: .button)
        let buttonID2 = generator.generateID(for: .button)
        let textInputID1 = generator.generateID(for: .textInput)
        let linkID1 = generator.generateID(for: .link)
        
        #expect(buttonID1 == "B1")
        #expect(buttonID2 == "B2")
        #expect(textInputID1 == "T1")
        #expect(linkID1 == "L1")
    }
    
    @Test("Generate ID with specific index")
    @MainActor
    func generateIDWithSpecificIndex() {
        let buttonID = generator.generateID(for: .button, index: 42)
        let textID = generator.generateID(for: .textInput, index: 99)
        
        #expect(buttonID == "B42")
        #expect(textID == "T99")
    }
    
    @Test("ID prefixes for all categories")
    @MainActor
    func idPrefixesForAllCategories() {
        let expectations: [(ElementCategory, String)] = [
            (.button, "B"),
            (.textInput, "T"),
            (.link, "L"),
            (.checkbox, "C"),
            (.radioButton, "R"),
            (.slider, "S"),
            (.menu, "M"),
            (.image, "I"),
            (.container, "G"),
            (.text, "X"),
            (.custom("CustomType"), "U")
        ]
        
        for (category, expectedPrefix) in expectations {
            generator.resetCounters(for: category)
            let id = generator.generateID(for: category)
            #expect(id == "\(expectedPrefix)1")
        }
    }
    
    // MARK: - ID Parsing Tests
    
    @Test("Parse valid IDs")
    @MainActor
    func parseValidIDs() {
        let testCases: [(String, ElementCategory, Int)] = [
            ("B1", .button, 1),
            ("B42", .button, 42),
            ("T123", .textInput, 123),
            ("L5", .link, 5),
            ("C10", .checkbox, 10),
            ("R7", .radioButton, 7),
            ("S3", .slider, 3),
            ("M99", .menu, 99),
            ("I2", .image, 2),
            ("G15", .container, 15),
            ("X8", .text, 8)
        ]
        
        for (id, expectedCategory, expectedIndex) in testCases {
            if let parsed = generator.parseID(id) {
                #expect(parsed.category == expectedCategory)
                #expect(parsed.index == expectedIndex)
            } else {
                Issue.record("Failed to parse valid ID: \(id)")
            }
        }
    }
    
    @Test("Parse invalid IDs")
    @MainActor
    func parseInvalidIDs() {
        let invalidIDs = [
            "",
            "B",
            "123",
            "B1.5",
            "B 1",
            "1B"
        ]
        
        for invalidID in invalidIDs {
            let parsed = generator.parseID(invalidID)
            #expect(parsed == nil, "Should fail to parse invalid ID: \(invalidID)")
        }
    }
    
    // MARK: - Counter Management Tests
    
    @Test("Reset counters for specific category")
    @MainActor
    func resetSpecificCategory() {
        generator.resetCounters()
        
        // Generate some IDs
        _ = generator.generateID(for: .button)
        _ = generator.generateID(for: .button)
        _ = generator.generateID(for: .textInput)
        
        // Check counts
        #expect(generator.currentCount(for: .button) == 2)
        #expect(generator.currentCount(for: .textInput) == 1)
        
        // Reset only button counter
        generator.resetCounters(for: .button)
        
        #expect(generator.currentCount(for: .button) == 0)
        #expect(generator.currentCount(for: .textInput) == 1) // Should remain unchanged
        
        // Generate new button ID should start from 1 again
        let newButtonID = generator.generateID(for: .button)
        #expect(newButtonID == "B1")
    }
    
    @Test("Reset all counters")
    @MainActor
    func resetAllCounters() {
        // Generate some IDs
        _ = generator.generateID(for: .button)
        _ = generator.generateID(for: .textInput)
        _ = generator.generateID(for: .link)
        
        // Reset all
        generator.resetCounters()
        
        // All counters should be 0
        #expect(generator.currentCount(for: .button) == 0)
        #expect(generator.currentCount(for: .textInput) == 0)
        #expect(generator.currentCount(for: .link) == 0)
    }
    
    @Test("Current count for unused category")
    @MainActor
    func currentCountForUnusedCategory() {
        generator.resetCounters()
        
        // Check count for category that hasn't been used
        #expect(generator.currentCount(for: .slider) == 0)
    }
    
    // MARK: - Thread Safety Tests
    
    @Test("Concurrent ID generation")
    @MainActor
    func concurrentIDGeneration() async {
        generator.resetCounters()
        
        // Generate IDs concurrently
        let iterations = 100
        var generatedIDs: Set<String> = []
        
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<iterations {
                group.addTask { [generator] in
                    await MainActor.run {
                        generator.generateID(for: .button)
                    }
                }
            }
            
            for await id in group {
                generatedIDs.insert(id)
            }
        }
        
        // All IDs should be unique
        #expect(generatedIDs.count == iterations)
        
        // Counter should reflect all generations
        #expect(generator.currentCount(for: .button) == iterations)
    }
    
    // MARK: - Edge Cases
    
    @Test("Generate ID with zero index")
    @MainActor
    func generateIDWithZeroIndex() {
        let id = generator.generateID(for: .button, index: 0)
        #expect(id == "B0")
    }
    
    @Test("Generate ID with large index")
    @MainActor
    func generateIDWithLargeIndex() {
        let id = generator.generateID(for: .textInput, index: 999999)
        #expect(id == "T999999")
    }
    
    @Test("Custom category ID generation")
    @MainActor
    func customCategoryIDGeneration() {
        generator.resetCounters()
        
        let customCategory = ElementCategory.custom("MyCustomType")
        let id1 = generator.generateID(for: customCategory)
        let id2 = generator.generateID(for: customCategory)
        
        #expect(id1 == "U1")
        #expect(id2 == "U2")
        
        // Parse should return custom category
        if let parsed = generator.parseID("U1") {
            #expect(parsed.category == .custom("U"))
            #expect(parsed.index == 1)
        } else {
            Issue.record("Failed to parse custom category ID")
        }
    }
}