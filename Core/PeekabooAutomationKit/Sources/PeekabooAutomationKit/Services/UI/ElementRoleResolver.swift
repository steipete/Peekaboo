import PeekabooFoundation

@_spi(Testing) public struct ElementRoleInfo: Sendable {
    public let role: String
    public let roleDescription: String?
    public let isEditable: Bool

    public init(role: String, roleDescription: String?, isEditable: Bool) {
        self.role = role
        self.roleDescription = roleDescription
        self.isEditable = isEditable
    }
}

@_spi(Testing) public enum ElementRoleResolver {
    @_spi(Testing) public static func resolveType(baseType: ElementType, info: ElementRoleInfo) -> ElementType {
        guard baseType == .group else {
            return baseType
        }

        if info.isEditable {
            return .textField
        }

        if let description = info.roleDescription?.lowercased() {
            if description.contains("text field") ||
                description.contains("text input") ||
                description.contains("search field")
            {
                return .textField
            }
        }

        return baseType
    }
}
