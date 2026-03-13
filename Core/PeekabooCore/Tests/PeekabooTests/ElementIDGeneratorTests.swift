import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@MainActor
struct ElementIDGeneratorTests {
    let generator = ElementIDGenerator()

    // MARK: - ID Generation Tests

    @Test
    @MainActor
    func `Generate IDs for different categories`() {
        // Reset to start fresh
        self.generator.resetCounters()

        // Generate IDs for different categories
        let buttonID1 = self.generator.generateID(for: .button)
        let buttonID2 = self.generator.generateID(for: .button)
        let textInputID1 = self.generator.generateID(for: .textInput)
        let linkID1 = self.generator.generateID(for: .link)

        #expect(buttonID1 == "B1")
        #expect(buttonID2 == "B2")
        #expect(textInputID1 == "T1")
        #expect(linkID1 == "L1")
    }

    @Test
    @MainActor
    func `Generate ID with specific index`() {
        let buttonID = self.generator.generateID(for: .button, index: 42)
        let textID = self.generator.generateID(for: .textInput, index: 99)

        #expect(buttonID == "B42")
        #expect(textID == "T99")
    }

    @Test
    @MainActor
    func `ID prefixes for all categories`() {
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
            (.custom("CustomType"), "U"),
        ]

        for (category, expectedPrefix) in expectations {
            self.generator.resetCounters(for: category)
            let id = self.generator.generateID(for: category)
            #expect(id == "\(expectedPrefix)1")
        }
    }

    // MARK: - ID Parsing Tests

    @Test
    @MainActor
    func `Parse valid IDs`() {
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
            ("X8", .text, 8),
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

    @Test
    @MainActor
    func `Parse invalid IDs`() {
        let invalidIDs = [
            "",
            "B",
            "123",
            "B1.5",
            "B 1",
            "1B",
        ]

        for invalidID in invalidIDs {
            let parsed = self.generator.parseID(invalidID)
            #expect(parsed == nil, "Should fail to parse invalid ID: \(invalidID)")
        }
    }

    // MARK: - Counter Management Tests

    @Test
    @MainActor
    func `Reset counters for specific category`() {
        self.generator.resetCounters()

        // Generate some IDs
        _ = self.generator.generateID(for: .button)
        _ = self.generator.generateID(for: .button)
        _ = self.generator.generateID(for: .textInput)

        // Check counts
        #expect(self.generator.currentCount(for: .button) == 2)
        #expect(self.generator.currentCount(for: .textInput) == 1)

        // Reset only button counter
        self.generator.resetCounters(for: .button)

        #expect(self.generator.currentCount(for: .button) == 0)
        #expect(self.generator.currentCount(for: .textInput) == 1) // Should remain unchanged

        // Generate new button ID should start from 1 again
        let newButtonID = self.generator.generateID(for: .button)
        #expect(newButtonID == "B1")
    }

    @Test
    @MainActor
    func `Reset all counters`() {
        // Generate some IDs
        _ = self.generator.generateID(for: .button)
        _ = self.generator.generateID(for: .textInput)
        _ = self.generator.generateID(for: .link)

        // Reset all
        self.generator.resetCounters()

        // All counters should be 0
        #expect(self.generator.currentCount(for: .button) == 0)
        #expect(self.generator.currentCount(for: .textInput) == 0)
        #expect(self.generator.currentCount(for: .link) == 0)
    }

    @Test
    @MainActor
    func `Current count for unused category`() {
        self.generator.resetCounters()

        // Check count for category that hasn't been used
        #expect(self.generator.currentCount(for: .slider) == 0)
    }

    // MARK: - Thread Safety Tests

    @Test
    @MainActor
    func `Concurrent ID generation`() async {
        self.generator.resetCounters()

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
        #expect(self.generator.currentCount(for: .button) == iterations)
    }

    // MARK: - Edge Cases

    @Test
    @MainActor
    func `Generate ID with zero index`() {
        let id = self.generator.generateID(for: .button, index: 0)
        #expect(id == "B0")
    }

    @Test
    @MainActor
    func `Generate ID with large index`() {
        let id = self.generator.generateID(for: .textInput, index: 999_999)
        #expect(id == "T999999")
    }

    @Test
    @MainActor
    func `Custom category ID generation`() {
        self.generator.resetCounters()

        let customCategory = ElementCategory.custom("MyCustomType")
        let id1 = self.generator.generateID(for: customCategory)
        let id2 = self.generator.generateID(for: customCategory)

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
