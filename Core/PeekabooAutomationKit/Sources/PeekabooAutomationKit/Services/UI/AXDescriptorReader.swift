import AppKit
@preconcurrency import AXorcist
import CoreGraphics

/// Reads the small descriptor surface element detection needs from AX elements.
@_spi(Testing) public enum AXDescriptorReader {
    @_spi(Testing) public struct Descriptor: Equatable {
        public let frame: CGRect
        public let role: String
        public let title: String?
        public let label: String?
        public let value: String?
        public let description: String?
        public let help: String?
        public let roleDescription: String?
        public let identifier: String?
        public let isEnabled: Bool
        public let placeholder: String?
    }

    private struct AttributeValues {
        let position: CGPoint?
        let size: CGSize?
        let role: String?
        let title: String?
        let label: String?
        let value: String?
        let description: String?
        let help: String?
        let roleDescription: String?
        let identifier: String?
        let isEnabled: Bool?
        let placeholder: String?
    }

    private static let descriptorAttributeNames: [String] = [
        AttributeName.position,
        AttributeName.size,
        AttributeName.role,
        AttributeName.title,
        "AXLabel",
        AttributeName.value,
        AttributeName.description,
        AttributeName.help,
        AttributeName.roleDescription,
        AttributeName.identifier,
        AttributeName.enabled,
        AttributeName.placeholderValue,
    ]

    @MainActor
    static func describe(_ element: Element) -> Descriptor? {
        guard let attributes = self.copyAttributes(for: element) else {
            return self.describeWithSingleAttributeReads(element)
        }

        let frame = CGRect(origin: attributes.position ?? .zero, size: attributes.size ?? .zero)
        guard self.isUsefulFrame(frame) else { return nil }

        return Descriptor(
            frame: frame,
            role: attributes.role ?? "Unknown",
            title: attributes.title,
            label: attributes.label,
            value: attributes.value,
            description: attributes.description,
            help: attributes.help,
            roleDescription: attributes.roleDescription,
            identifier: attributes.identifier,
            isEnabled: attributes.isEnabled ?? false,
            placeholder: attributes.placeholder)
    }

    @MainActor
    private static func describeWithSingleAttributeReads(_ element: Element) -> Descriptor? {
        let frame = element.frame() ?? .zero
        guard self.isUsefulFrame(frame) else { return nil }

        return Descriptor(
            frame: frame,
            role: element.role() ?? "Unknown",
            title: element.title(),
            label: element.label(),
            value: element.stringValue(),
            description: element.descriptionText(),
            help: element.help(),
            roleDescription: element.roleDescription(),
            identifier: element.identifier(),
            isEnabled: element.isEnabled() ?? false,
            placeholder: element.placeholderValue())
    }

    @MainActor
    private static func copyAttributes(for element: Element) -> AttributeValues? {
        var rawValues: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            element.underlyingElement,
            self.descriptorAttributeNames as CFArray,
            [],
            &rawValues)
        guard error == .success,
              let values = rawValues as? [Any],
              values.count == self.descriptorAttributeNames.count
        else {
            return nil
        }

        let valueByName = Dictionary(uniqueKeysWithValues: zip(self.descriptorAttributeNames, values))
        // `AXUIElementCopyMultipleAttributeValues` turns missing attributes into AXError-valued
        // AXValues. The typed readers below treat those as nil while keeping this pass to one AX round-trip.
        return AttributeValues(
            position: self.cgPointValue(valueByName[AttributeName.position]),
            size: self.cgSizeValue(valueByName[AttributeName.size]),
            role: self.stringValue(valueByName[AttributeName.role]),
            title: self.stringValue(valueByName[AttributeName.title]),
            label: self.stringValue(valueByName["AXLabel"]),
            value: self.stringValue(valueByName[AttributeName.value]),
            description: self.stringValue(valueByName[AttributeName.description]),
            help: self.stringValue(valueByName[AttributeName.help]),
            roleDescription: self.stringValue(valueByName[AttributeName.roleDescription]),
            identifier: self.stringValue(valueByName[AttributeName.identifier]),
            isEnabled: self.boolValue(valueByName[AttributeName.enabled]),
            placeholder: self.stringValue(valueByName[AttributeName.placeholderValue]))
    }

    @_spi(Testing) public static func stringValue(_ value: Any?) -> String? {
        value as? String
    }

    @_spi(Testing) public static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        return (value as? NSNumber)?.boolValue
    }

    @_spi(Testing) public static func cgPointValue(_ value: Any?) -> CGPoint? {
        guard let axValue = self.axValue(value),
              AXValueGetType(axValue) == .cgPoint
        else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    @_spi(Testing) public static func cgSizeValue(_ value: Any?) -> CGSize? {
        guard let axValue = self.axValue(value),
              AXValueGetType(axValue) == .cgSize
        else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func axValue(_ value: Any?) -> AXValue? {
        guard let value else { return nil }
        let cfValue = value as CFTypeRef
        guard CFGetTypeID(cfValue) == AXValueGetTypeID() else { return nil }
        return unsafeDowncast(cfValue, to: AXValue.self)
    }

    private static func isUsefulFrame(_ frame: CGRect) -> Bool {
        frame.width > 5 && frame.height > 5
    }
}

private enum AttributeName {
    static let position = "AXPosition"
    static let size = "AXSize"
    static let role = "AXRole"
    static let title = "AXTitle"
    static let value = "AXValue"
    static let description = "AXDescription"
    static let help = "AXHelp"
    static let roleDescription = "AXRoleDescription"
    static let identifier = "AXIdentifier"
    static let enabled = "AXEnabled"
    static let placeholderValue = "AXPlaceholderValue"
}
