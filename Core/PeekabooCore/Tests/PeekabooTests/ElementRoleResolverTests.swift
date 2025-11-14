import PeekabooFoundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("Element Role Resolver", .tags(.fast))
struct ElementRoleResolverTests {
    @Test("Editable groups become text fields")
    func editableGroup() {
        let info = ElementRoleInfo(
            role: "AXGroup",
            roleDescription: nil,
            isEditable: true)

        let resolved = ElementRoleResolver.resolveType(baseType: .group, info: info)
        #expect(resolved == .textField)
    }

    @Test("Role description hint promotes group")
    func roleDescriptionPromotion() {
        let info = ElementRoleInfo(
            role: "AXGroup",
            roleDescription: "text field",
            isEditable: false)

        let resolved = ElementRoleResolver.resolveType(baseType: .group, info: info)
        #expect(resolved == .textField)
    }

    @Test("Other groups stay grouped")
    func plainGroup() {
        let info = ElementRoleInfo(
            role: "AXGroup",
            roleDescription: "group",
            isEditable: false)

        let resolved = ElementRoleResolver.resolveType(baseType: .group, info: info)
        #expect(resolved == .group)
    }
}
