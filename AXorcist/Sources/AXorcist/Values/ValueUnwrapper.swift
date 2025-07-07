import ApplicationServices
import CoreGraphics // For CGPoint, CGSize etc.
import Foundation

// debug() is assumed to be globally available from Logging.swift
// Accessibility constants are now available through namespaced enums like AXAttributeNames, AXRoleNames, etc.

// MARK: - ValueUnwrapper Utility
struct ValueUnwrapper {
    @MainActor
    static func unwrap(_ cfValue: CFTypeRef?, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Any? {
        func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
        guard let value = cfValue else { return nil }
        let typeID = CFGetTypeID(value)

        return unwrapByTypeID(
            value,
            typeID: typeID,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }

    @MainActor
    private static func unwrapByTypeID(
        _ value: CFTypeRef,
        typeID: CFTypeID,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> Any? {
        func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }

        switch typeID {
        case ApplicationServices.AXUIElementGetTypeID():
            return value as! AXUIElement
        case ApplicationServices.AXValueGetTypeID():
            return unwrapAXValue(
                value,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
        case CFStringGetTypeID():
            return (value as! CFString) as String
        case CFAttributedStringGetTypeID():
            return (value as! NSAttributedString).string
        case CFBooleanGetTypeID():
            return CFBooleanGetValue((value as! CFBoolean))
        case CFNumberGetTypeID():
            return value as! NSNumber
        case CFArrayGetTypeID():
            return unwrapCFArray(
                value,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
        case CFDictionaryGetTypeID():
            return unwrapCFDictionary(
                value,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
        default:
            let typeDescription = CFCopyTypeIDDescription(typeID) as String? ?? "Unknown"
            dLog("ValueUnwrapper: Unhandled CFTypeID: \(typeID) - \(typeDescription). Returning raw value.")
            return value
        }
    }

    @MainActor
    private static func unwrapAXValue(
        _ value: CFTypeRef,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> Any? {
        func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }

        let axVal = value as! AXValue
        let axValueType = AXValueGetType(axVal)

        // Handle special boolean type
        if axValueType.rawValue == 4 { // kAXValueBooleanType (private)
            var boolResult: DarwinBoolean = false
            if AXValueGetValue(axVal, axValueType, &boolResult) {
                return boolResult.boolValue
            }
        }

        return unwrapAXValueByType(axVal, axValueType: axValueType, dLog: dLog)
    }

    @MainActor
    private static func unwrapAXValueByType(
        _ axVal: AXValue,
        axValueType: AXValueType,
        dLog: (String) -> Void
    ) -> Any? {
        switch axValueType {
        case .cgPoint:
            var point = CGPoint.zero
            return AXValueGetValue(axVal, .cgPoint, &point) ? point : nil
        case .cgSize:
            var size = CGSize.zero
            return AXValueGetValue(axVal, .cgSize, &size) ? size : nil
        case .cgRect:
            var rect = CGRect.zero
            return AXValueGetValue(axVal, .cgRect, &rect) ? rect : nil
        case .cfRange:
            var cfRange = CFRange()
            return AXValueGetValue(axVal, .cfRange, &cfRange) ? cfRange : nil
        case .axError:
            var axErrorValue: AXError = .success
            return AXValueGetValue(axVal, .axError, &axErrorValue) ? axErrorValue : nil
        case .illegal:
            dLog("ValueUnwrapper: Encountered AXValue with type .illegal")
            return nil
        @unknown default:
            dLog("ValueUnwrapper: AXValue with unhandled AXValueType: \(stringFromAXValueType(axValueType)).")
            return axVal
        }
    }

    @MainActor
    private static func unwrapCFArray(
        _ value: CFTypeRef,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> [Any?] {
        let cfArray = value as! CFArray
        var swiftArray: [Any?] = []

        for index in 0..<CFArrayGetCount(cfArray) {
            guard let elementPtr = CFArrayGetValueAtIndex(cfArray, index) else {
                swiftArray.append(nil)
                continue
            }
            swiftArray.append(unwrap(
                Unmanaged<CFTypeRef>.fromOpaque(elementPtr).takeUnretainedValue(),
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            ))
        }
        return swiftArray
    }

    @MainActor
    private static func unwrapCFDictionary(
        _ value: CFTypeRef,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> [String: Any?] {
        func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }

        let cfDict = value as! CFDictionary
        var swiftDict: [String: Any?] = [:]
        // Attempt to bridge to Swift dictionary directly if possible
        if let nsDict = cfDict as? [String: AnyObject] {
            for (key, val) in nsDict {
                swiftDict[key] = unwrap(
                    val,
                    isDebugLoggingEnabled: isDebugLoggingEnabled,
                    currentDebugLogs: &currentDebugLogs
                )
            }
        } else {
            // Fallback for more complex CFDictionary structures if direct bridging fails
            dLog(
                "ValueUnwrapper: Failed to bridge CFDictionary to [String: AnyObject]. " +
                    "Full CFDictionary iteration not yet implemented here."
            )
        }
        return swiftDict
    }
}
