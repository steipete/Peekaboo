import Testing
@testable import PeekabooAgentRuntime
@_spi(Testing) import PeekabooAutomationKit
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite(.tags(.fast))
struct ElementLabelResolverTests {
    @Test
    func `Uses existing non-generic label`() {
        let info = ElementLabelInfo(
            role: "AXButton",
            label: "Submit",
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: nil,
            placeholder: nil)

        let resolved = ElementLabelResolver.resolve(info: info, childTexts: [], identifierCleaner: { $0 })
        #expect(resolved == "Submit")
    }

    @Test
    func `Falls back to child text when label is generic`() {
        let info = ElementLabelInfo(
            role: "AXButton",
            label: "button",
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: nil,
            placeholder: nil)

        let resolved = ElementLabelResolver.resolve(info: info, childTexts: ["Allow"], identifierCleaner: { $0 })
        #expect(resolved == "Allow")
    }

    @Test
    func `Falls back to identifier cleaning when no text available`() {
        let info = ElementLabelInfo(
            role: "AXButton",
            label: nil,
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: "bubble-allow-button",
            placeholder: nil)

        let resolved = ElementLabelResolver.resolve(info: info, childTexts: [], identifierCleaner: { _ in "Allow" })
        #expect(resolved == "Allow")
    }

    @Test
    func `Only unlabeled buttons need child text lookup`() {
        let labeledButton = ElementLabelInfo(
            role: "AXButton",
            label: "Submit",
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: nil,
            placeholder: nil)
        let genericButton = ElementLabelInfo(
            role: "AXButton",
            label: "button",
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: nil,
            placeholder: nil)
        let describedButton = ElementLabelInfo(
            role: "AXButton",
            label: nil,
            title: nil,
            value: nil,
            roleDescription: nil,
            description: "Allow",
            identifier: nil,
            placeholder: nil)
        let group = ElementLabelInfo(
            role: "AXGroup",
            label: nil,
            title: nil,
            value: nil,
            roleDescription: nil,
            description: nil,
            identifier: nil,
            placeholder: nil)

        #expect(ElementLabelResolver.needsChildTexts(info: labeledButton) == false)
        #expect(ElementLabelResolver.needsChildTexts(info: genericButton))
        #expect(ElementLabelResolver.needsChildTexts(info: describedButton) == false)
        #expect(ElementLabelResolver.needsChildTexts(info: group) == false)
    }
}
