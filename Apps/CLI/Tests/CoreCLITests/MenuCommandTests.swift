//
//  MenuCommandTests.swift
//  PeekabooCLI
//

import Testing
@testable import PeekabooCLI

struct MenuCommandSelectionNormalizationTests {
    @Test
    func `Treat --item containing '>' as --path`() {
        let input = "View > Show View Options"
        let normalized = normalizeMenuSelection(item: input, path: nil)
        #expect(normalized.item == nil)
        #expect(normalized.path == input)
        #expect(normalized.convertedFromItem)
    }

    @Test
    func `Preserve explicit path when provided`() {
        let normalized = normalizeMenuSelection(item: "File", path: "Apple > About This Mac")
        #expect(normalized.item == "File")
        #expect(normalized.path == "Apple > About This Mac")
        #expect(normalized.convertedFromItem == false)
    }

    @Test
    func `Plain item stays untouched`() {
        let normalized = normalizeMenuSelection(item: "New Window", path: nil)
        #expect(normalized.item == "New Window")
        #expect(normalized.path == nil)
        #expect(normalized.convertedFromItem == false)
    }
}
