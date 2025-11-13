//
//  MenuCommandTests.swift
//  PeekabooCLI
//

import Testing
@testable import PeekabooCLI

@Suite("Menu command input normalization")
struct MenuCommandSelectionNormalizationTests {
    @Test("Treat --item containing '>' as --path")
    func itemWithPathDelimiterBecomesPath() {
        let input = "View > Show View Options"
        let normalized = normalizeMenuSelection(item: input, path: nil)
        #expect(normalized.item == nil)
        #expect(normalized.path == input)
        #expect(normalized.convertedFromItem)
    }

    @Test("Preserve explicit path when provided")
    func explicitPathRemains() {
        let normalized = normalizeMenuSelection(item: "File", path: "Apple > About This Mac")
        #expect(normalized.item == "File")
        #expect(normalized.path == "Apple > About This Mac")
        #expect(normalized.convertedFromItem == false)
    }

    @Test("Plain item stays untouched")
    func simpleItemStaysItem() {
        let normalized = normalizeMenuSelection(item: "New Window", path: nil)
        #expect(normalized.item == "New Window")
        #expect(normalized.path == nil)
        #expect(normalized.convertedFromItem == false)
    }
}
