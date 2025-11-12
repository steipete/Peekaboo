import Foundation

// GlobalAXLogger is assumed available

public extension Element {
    /// Computes a human-readable name for the element based on various attributes.
    /// This is useful for logging and debugging, and can be part of the `collectAll` output.
    @MainActor
    func computedName() -> String? {
        let elementDescription = briefDescription(option: .raw)

        func nonEmpty(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        let candidates: [(source: String, provider: () -> String?)] = [
            ("AXTitle", { nonEmpty(self.title()) }),
            ("AXValue", {
                guard let rawValue = self.value() as? String, !rawValue.isEmpty else { return nil }
                return String(rawValue.prefix(50))
            }),
            ("AXIdentifier", { nonEmpty(self.identifier()) }),
            ("AXDescription", { nonEmpty(self.descriptionText()) }),
            ("AXHelp", { nonEmpty(self.help()) }),
            ("AXPlaceholderValue", {
                let placeholder = self.attribute(Attribute<String>(AXAttributeNames.kAXPlaceholderValueAttribute))
                return nonEmpty(placeholder)
            })
        ]

        for candidate in candidates {
            if let value = candidate.provider() {
                return logComputedName(
                    source: candidate.source,
                    value: value,
                    elementDescription: elementDescription
                )
            }
        }

        if let roleName = nonEmpty(role()) {
            let cleanRole = roleName.replacingOccurrences(of: "AX", with: "")
            return logComputedName(
                source: "AXRole",
                value: cleanRole,
                elementDescription: elementDescription
            )
        }

        logMissingComputedName(elementDescription: elementDescription)
        return nil
    }

    private func logComputedName(source: String, value: String, elementDescription: String) -> String {
        let message = [
            "ComputedName: Using \(source)",
            "'\(value)' for \(elementDescription)"
        ].joined(separator: " ")
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: message))
        return value
    }

    private func logMissingComputedName(elementDescription: String) {
        let message = [
            "ComputedName: No suitable attribute found for",
            "\(elementDescription). Returning nil."
        ].joined(separator: " ")
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: message))
    }
}
