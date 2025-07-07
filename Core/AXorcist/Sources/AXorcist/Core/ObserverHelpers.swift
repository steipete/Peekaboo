// ObserverHelpers.swift - Helper functions for AXObserver operations

import ApplicationServices
import Foundation

// MARK: - Helper for userInfo conversion

@MainActor
func convertCFValueToSwift(_ cfValue: CFTypeRef?) -> Any? {
    guard let cfValue else { return nil }
    let typeID = CFGetTypeID(cfValue)

    switch typeID {
    case CFStringGetTypeID():
        return cfValue as? String
    case CFNumberGetTypeID():
        return cfValue as? NSNumber // Could be Int, Double, Bool (via NSNumber bridging)
    case CFBooleanGetTypeID():
        // Ensure correct conversion for CFBoolean
        if CFEqual(cfValue, CFConstants.cfBooleanTrue) {
            return true
        } else if CFEqual(cfValue, CFConstants.cfBooleanFalse) {
            return false
        }
        // Fallback for other CFBoolean representations if any, or if direct Bool bridging works
        if let boolVal = cfValue as? Bool {
            return boolVal
        }
        axWarningLog("Could not convert CFBoolean to Bool: \(String(describing: cfValue))")
        return nil // Or handle as error
    case CFArrayGetTypeID():
        // Swift arrays bridge to CFArray, and CFArray can be cast to NSArray / [AnyObject]
        if let cfArray = cfValue as? [CFTypeRef] { // or cfValue as? NSArray
            return cfArray.compactMap { convertCFValueToSwift($0) }
        }
        axWarningLog("Failed to convert CFArray from userInfo.")
        return cfValue // Return raw CFArray if conversion fails for some reason
    case CFDictionaryGetTypeID():
        if let cfDict = cfValue as? [CFString: CFTypeRef] { // or cfValue as? NSDictionary
            var swiftDict = [String: Any]()
            for (key, value) in cfDict {
                swiftDict[key as String] = convertCFValueToSwift(value)
            }
            return swiftDict
        }
        axWarningLog("Failed to convert nested CFDictionary from userInfo.")
        return cfValue // Return raw CFDictionary if conversion fails
    case AXUIElementGetTypeID():
        return cfValue as! AXUIElement // Should be safe to force unwrap if type matches
    // Add other common CF types if necessary, e.g., CFURL, CFDate
    default:
        axDebugLog("Unhandled CFTypeRef in convertCFValueToSwift: typeID \(typeID). Value: \(cfValue)")
        return cfValue // Return raw CFTypeRef if unhandled, caller might know what to do
    }
}
