import ApplicationServices
import CoreGraphics // For CGPoint, CGSize etc.
import Foundation

// GlobalAXLogger is expected to be available in this module (AXorcistLib)

// MARK: - ValueUnwrapper Utility

enum ValueUnwrapper {
    // MARK: Internal

    @MainActor
    static func unwrap(_ cfValue: CFTypeRef?) -> Any? {
        guard let value = cfValue else { return nil }
        let typeID = CFGetTypeID(value)

        return unwrapByTypeID(
            value,
            typeID: typeID
        )
    }

    // MARK: Private

    @MainActor
    private static func unwrapByTypeID(
        _ value: CFTypeRef,
        typeID: CFTypeID
    ) -> Any? {
        switch typeID {
        case ApplicationServices.AXUIElementGetTypeID():
            return value as! AXUIElement
        case ApplicationServices.AXValueGetTypeID():
            return unwrapAXValue(value)
        case CFStringGetTypeID():
            return (value as! CFString) as String
        case CFAttributedStringGetTypeID():
            return (value as! NSAttributedString).string
        case CFBooleanGetTypeID():
            return CFBooleanGetValue((value as! CFBoolean))
        case CFNumberGetTypeID():
            return value as! NSNumber
        case CFArrayGetTypeID():
            return unwrapCFArray(value)
        case CFDictionaryGetTypeID():
            return unwrapCFDictionary(value)
        default:
            let typeDescription = CFCopyTypeIDDescription(typeID) as String? ?? "Unknown"
            axDebugLog("Unhandled CFTypeID: \(typeID) - \(typeDescription). Returning raw value.")
            return value
        }
    }

    @MainActor
    private static func unwrapAXValue(
        _ value: CFTypeRef
    ) -> Any? {
        let axVal = value as! AXValue
        let axValueType = axVal.valueType

        // Log the AXValueType
        axDebugLog(
            "ValueUnwrapper.unwrapAXValue: Encountered AXValue with type: \(axValueType) (rawValue: \(axValueType.rawValue))"
        )

        // Handle special boolean type
        if axValueType.rawValue == 4 { // kAXValueBooleanType (private)
            var boolResult: DarwinBoolean = false
            if AXValueGetValue(axVal, axValueType, &boolResult) {
                return boolResult.boolValue
            }
        }

        // Use new AXValue extensions for cleaner unwrapping
        let unwrappedExtensionValue = axVal.value()
        axDebugLog(
            "ValueUnwrapper.unwrapAXValue: axVal.value() returned: \(String(describing: unwrappedExtensionValue)) for type: \(axValueType)"
        )
        return unwrappedExtensionValue
    }

    @MainActor
    private static func unwrapCFArray(
        _ value: CFTypeRef
    ) -> [Any?] {
        let cfArray = value as! CFArray
        var swiftArray: [Any?] = []

        for index in 0 ..< CFArrayGetCount(cfArray) {
            guard let elementPtr = CFArrayGetValueAtIndex(cfArray, index) else {
                swiftArray.append(nil)
                continue
            }
            swiftArray.append(unwrap( // Recursive call uses new unwrap signature
                Unmanaged<CFTypeRef>.fromOpaque(elementPtr).takeUnretainedValue()
            ))
        }
        return swiftArray
    }

    @MainActor
    private static func unwrapCFDictionary(
        _ value: CFTypeRef
    ) -> [String: Any?] {
        let cfDict = value as! CFDictionary
        var swiftDict: [String: Any?] = [:]

        if let nsDict = cfDict as? [String: AnyObject] {
            for (key, val) in nsDict {
                swiftDict[key] = unwrap(val) // Recursive call uses new unwrap signature
            }
        } else {
            axWarningLog(
                "Failed to bridge CFDictionary to [String: AnyObject]. Full CFDictionary iteration not yet implemented here."
            )
        }
        return swiftDict
    }
}
