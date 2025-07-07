// Element+TypeConversion.swift - Type conversion functionality for Element

import ApplicationServices
import Foundation

extension Element {
    @MainActor
    func convertCFTypeToSwiftType<T>(_ cfValue: CFTypeRef, attribute: Attribute<T>) -> T? {
        // Try specific type conversions first
        if let converted = convertToSpecificType(cfValue, targetType: T.self) as? T {
            return converted
        }

        // Handle Any/AnyObject types
        if T.self == Any.self || T.self == AnyObject.self {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "Attribute \(attribute.rawValue): T is Any/AnyObject. Using ValueUnwrapper."
            ))
            return ValueUnwrapper.unwrap(cfValue) as? T
        }

        // Try direct cast
        if let directCast = cfValue as? T {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "Basic conversion succeeded with direct cast for T = \(String(describing: T.self)), " +
                    "Attribute: \(attribute.rawValue)."
            ))
            return directCast
        }

        // Fall back to ValueUnwrapper
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "Attempting ValueUnwrapper for T = \(String(describing: T.self)), " +
                "Attribute: \(attribute.rawValue)."
        ))
        return ValueUnwrapper.unwrap(cfValue) as? T
    }

    private func convertToSpecificType(_ cfValue: CFTypeRef, targetType: Any.Type) -> Any? {
        let cfTypeID = CFGetTypeID(cfValue)

        switch targetType {
        case is String.Type:
            return convertToString(cfValue, cfTypeID: cfTypeID)
        case is Bool.Type:
            return convertToBool(cfValue, cfTypeID: cfTypeID)
        case is Int.Type:
            return convertToInt(cfValue, cfTypeID: cfTypeID)
        case is AXUIElement.Type:
            return convertToAXUIElement(cfValue, cfTypeID: cfTypeID)
        default:
            return nil
        }
    }

    private func convertToString(_ cfValue: CFTypeRef, cfTypeID: CFTypeID) -> String? {
        if cfTypeID == CFStringGetTypeID() {
            let cfString = cfValue as! CFString
            return cfString as String
        } else if cfTypeID == CFAttributedStringGetTypeID() {
            let attrString = cfValue as! NSAttributedString
            return attrString.string
        }
        return nil
    }

    private func convertToBool(_ cfValue: CFTypeRef, cfTypeID: CFTypeID) -> Bool? {
        if cfTypeID == CFBooleanGetTypeID() {
            let cfBool = cfValue as! CFBoolean
            return CFBooleanGetValue(cfBool)
        }
        return nil
    }

    private func convertToInt(_ cfValue: CFTypeRef, cfTypeID: CFTypeID) -> Int? {
        if cfTypeID == CFNumberGetTypeID() {
            let cfNumber = cfValue as! CFNumber
            var intValue = 0
            if CFNumberGetValue(cfNumber, .sInt64Type, &intValue) {
                return intValue
            }
        }
        return nil
    }

    private func convertToAXUIElement(_ cfValue: CFTypeRef, cfTypeID: CFTypeID) -> AXUIElement? {
        if cfTypeID == AXUIElementGetTypeID() {
            let element = cfValue as! AXUIElement
            return element
        }
        return nil
    }
}
