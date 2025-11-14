import PeekabooFoundation

struct ElementRoleInfo {
    let role: String
    let roleDescription: String?
    let isEditable: Bool
}

enum ElementRoleResolver {
    static func resolveType(baseType: ElementType, info: ElementRoleInfo) -> ElementType {
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
