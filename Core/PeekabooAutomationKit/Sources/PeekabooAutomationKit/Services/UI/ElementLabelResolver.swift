import Foundation

@_spi(Testing) public struct ElementLabelInfo: Sendable {
    public let role: String
    public let label: String?
    public let title: String?
    public let value: String?
    public let roleDescription: String?
    public let description: String?
    public let identifier: String?
    public let placeholder: String?

    public init(
        role: String,
        label: String?,
        title: String?,
        value: String?,
        roleDescription: String?,
        description: String?,
        identifier: String?,
        placeholder: String?)
    {
        self.role = role
        self.label = label
        self.title = title
        self.value = value
        self.roleDescription = roleDescription
        self.description = description
        self.identifier = identifier
        self.placeholder = placeholder
    }
}

@_spi(Testing) public enum ElementLabelResolver {
    @_spi(Testing) public static func resolve(
        info: ElementLabelInfo,
        childTexts: [String],
        identifierCleaner: (String) -> String)
        -> String?
    {
        let baseLabel = ElementLabelResolver.firstNonGeneric(
            candidates: [info.label, info.title, info.value, info.placeholder, info.roleDescription])

        guard info.role.lowercased() == "axbutton" else {
            return baseLabel
        }

        if let baseLabel {
            return baseLabel
        }

        if let description = ElementLabelResolver.normalize(info.description) {
            return description
        }

        if let child = childTexts.compactMap(ElementLabelResolver.normalize).first {
            return child
        }

        if let identifier = info.identifier,
           let normalized = ElementLabelResolver.normalize(identifier)
        {
            return identifierCleaner(normalized)
        }

        return nil
    }

    private static func firstNonGeneric(candidates: [String?]) -> String? {
        for candidate in candidates {
            if let normalized = self.normalize(candidate), normalized.lowercased() != "button" {
                return normalized
            }
        }
        return nil
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
