import Testing
@testable import PeekabooCore

@Suite("Element Label Resolver", .tags(.fast))
struct ElementLabelResolverTests {
    @Test("Uses existing non-generic label")
    func usesExistingLabel() {
        let info = ElementLabelInfo(
            role: "AXButton",
            label: "Submit",
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: nil
        )

        let resolved = ElementLabelResolver.resolve(info: info, childTexts: [], identifierCleaner: { $0 })
        #expect(resolved == "Submit")
    }

    @Test("Falls back to child text when label is generic")
    func usesChildText() {
        let info = ElementLabelInfo(
            role: "AXButton",
            label: "button",
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: nil
        )

        let resolved = ElementLabelResolver.resolve(info: info, childTexts: ["Allow"], identifierCleaner: { $0 })
        #expect(resolved == "Allow")
    }

    @Test("Falls back to identifier cleaning when no text available")
    func usesIdentifier() {
        let info = ElementLabelInfo(
            role: "AXButton",
            label: nil,
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: "bubble-allow-button"
        )

        let resolved = ElementLabelResolver.resolve(info: info, childTexts: [], identifierCleaner: { _ in "Allow" })
        #expect(resolved == "Allow")
    }
}
