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
        return convertCFBoolean(cfValue)
    case CFArrayGetTypeID():
        return convertCFArray(cfValue)
    case CFDictionaryGetTypeID():
        return convertCFDictionary(cfValue)
    case AXUIElementGetTypeID():
        return cfValue as! AXUIElement // Should be safe to force unwrap if type matches
    // Add other common CF types if necessary, e.g., CFURL, CFDate
    default:
        axDebugLog("Unhandled CFTypeRef in convertCFValueToSwift: typeID \(typeID). Value: \(cfValue)")
        return cfValue // Return raw CFTypeRef if unhandled, caller might know what to do
    }
}

@MainActor
private func convertCFBoolean(_ cfValue: CFTypeRef) -> Bool? {
    if CFEqual(cfValue, CFConstants.cfBooleanTrue) {
        return true
    }
    if CFEqual(cfValue, CFConstants.cfBooleanFalse) {
        return false
    }
    if let boolVal = cfValue as? Bool {
        return boolVal
    }

    axWarningLog("Could not convert CFBoolean to Bool: \(String(describing: cfValue))")
    return nil
}

@MainActor
private func convertCFArray(_ cfValue: CFTypeRef) -> Any? {
    guard let cfArray = cfValue as? [CFTypeRef] else {
        axWarningLog("Failed to convert CFArray from userInfo.")
        return cfValue
    }
    return cfArray.compactMap { convertCFValueToSwift($0) }
}

@MainActor
private func convertCFDictionary(_ cfValue: CFTypeRef) -> Any? {
    guard let cfDict = cfValue as? [CFString: CFTypeRef] else {
        axWarningLog("Failed to convert nested CFDictionary from userInfo.")
        return cfValue
    }

    var swiftDict = [String: Any]()
    for (key, value) in cfDict {
        swiftDict[key as String] = convertCFValueToSwift(value)
    }
    return swiftDict
}
