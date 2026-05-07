import PeekabooFoundation

@_spi(Testing) public struct ElementTypeAdjustmentInput: Sendable, Equatable {
    public let role: String
    public let roleDescription: String?
    public let title: String?
    public let label: String?
    public let placeholder: String?
    public let isEditable: Bool

    public init(
        role: String,
        roleDescription: String?,
        title: String?,
        label: String?,
        placeholder: String?,
        isEditable: Bool)
    {
        self.role = role
        self.roleDescription = roleDescription
        self.title = title
        self.label = label
        self.placeholder = placeholder
        self.isEditable = isEditable
    }
}

/// Applies Peekaboo's text-field recovery heuristics to AX-derived element types.
@_spi(Testing) public enum ElementTypeAdjuster {
    private static let textFieldKeywords = ["email", "password", "username", "phone", "code"]

    public static func resolve(
        baseType: ElementType,
        input: ElementTypeAdjustmentInput,
        hasTextFieldDescendant: Bool)
        -> ElementType
    {
        let resolved = self.roleResolvedType(baseType: baseType, input: input)
        guard resolved == .group else {
            return resolved
        }

        if self.hasTextFieldHint(input) || hasTextFieldDescendant {
            return .textField
        }

        return resolved
    }

    public static func shouldScanForTextFieldDescendant(
        baseType: ElementType,
        input: ElementTypeAdjustmentInput)
        -> Bool
    {
        self.roleResolvedType(baseType: baseType, input: input) == .group && !self.hasTextFieldHint(input)
    }

    private static func roleResolvedType(baseType: ElementType, input: ElementTypeAdjustmentInput) -> ElementType {
        ElementRoleResolver.resolveType(
            baseType: baseType,
            info: ElementRoleInfo(
                role: input.role,
                roleDescription: input.roleDescription,
                isEditable: input.isEditable))
    }

    private static func hasTextFieldHint(_ input: ElementTypeAdjustmentInput) -> Bool {
        if input.placeholder?.isEmpty == false {
            return true
        }

        let loweredTitle = input.title?.lowercased()
        let loweredLabel = input.label?.lowercased()
        return loweredTitle.map { title in self.textFieldKeywords.contains(where: { title.contains($0) }) } ?? false ||
            loweredLabel.map { label in self.textFieldKeywords.contains(where: { label.contains($0) }) } ?? false
    }
}
