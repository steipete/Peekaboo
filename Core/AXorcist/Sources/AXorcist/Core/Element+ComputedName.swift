import Foundation

// GlobalAXLogger is assumed available

public extension Element {
    /// Computes a human-readable name for the element based on various attributes.
    /// This is useful for logging and debugging, and can be part of the `collectAll` output.
    @MainActor
    func computedName() -> String? {
        // Prioritize specific, descriptive attributes first
        if let title = self.title(), !title.isEmpty { // title() will become sync
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "ComputedName: Using AXTitle '\(title)' for \(self.briefDescription(option: .raw))"
            ))
            return title
        }
        if let value = self.value() as? String, !value.isEmpty { // value() will become sync
            // Be cautious with AXValue; it can be very long or non-descriptive.
            // Limit length and perhaps check for common non-descriptive patterns if needed.
            let truncatedValue = String(value.prefix(50))
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "ComputedName: Using AXValue '\(truncatedValue)' (truncated) for \(self.briefDescription(option: .raw))"
            ))
            return truncatedValue
        }
        if let identifier = self.identifier(), !identifier.isEmpty { // identifier() will become sync
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "ComputedName: Using AXIdentifier '\(identifier)' for \(self.briefDescription(option: .raw))"
            ))
            return identifier
        }
        if let desc = self.descriptionText(), !desc.isEmpty { // descriptionText() will become sync
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "ComputedName: Using AXDescription '\(desc)' for \(self.briefDescription(option: .raw))"
            ))
            return desc
        }
        if let help = self.help(), !help.isEmpty { // help() will become sync
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "ComputedName: Using AXHelp '\(help)' for \(self.briefDescription(option: .raw))"
            ))
            return help
        }
        // self.attribute() will become sync, so this call becomes sync
        if let placeholder = self.attribute(Attribute<String>(AXAttributeNames.kAXPlaceholderValueAttribute)),
           !placeholder.isEmpty
        {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "ComputedName: Using AXPlaceholderValue '\(placeholder)' for \(self.briefDescription(option: .raw))"
            ))
            return placeholder
        }

        // Fallback to role if no other descriptive attribute is found
        if let role = self.role(), !role.isEmpty { // role() will become sync
            // Make role more readable, e.g., "AXButton" -> "Button"
            let cleanRole = role.replacingOccurrences(of: "AX", with: "")
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "ComputedName: Falling back to AXRole '\(cleanRole)' for \(self.briefDescription(option: .raw))"
            ))
            return cleanRole
        }

        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "ComputedName: No suitable attribute found for \(self.briefDescription(option: .raw)). Returning nil."
        ))
        return nil // No suitable name found
    }
}
