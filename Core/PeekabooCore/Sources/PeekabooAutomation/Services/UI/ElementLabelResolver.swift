import Foundation

struct ElementLabelInfo {
    let role: String
    let label: String?
    let title: String?
    let value: String?
    let roleDescription: String?
    let description: String?
    let identifier: String?
    let placeholder: String?
}

enum ElementLabelResolver {
    static func resolve(
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
