import ApplicationServices
import Foundation

// Note: This file assumes AXAttributeNames.kAXRoleAttribute is available from AXAttributeNameConstants.swift
// and ValueUnwrapper is available from its respective file.

// MARK: - PathHintComponent Definition
@MainActor
struct PathHintComponent {
    let criteria: [String: String]

    init?(pathSegment: String, isDebugLoggingEnabled: Bool, axorcJsonLogEnabled: Bool, currentDebugLogs: inout [String]) {
        var parsedCriteria: [String: String] = [:]
        let pairs = pathSegment.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for pair in pairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if keyValue.count == 2 {
                parsedCriteria[String(keyValue[0])] = String(keyValue[1])
            } else {
                if isDebugLoggingEnabled && !axorcJsonLogEnabled {
                    currentDebugLogs.append(AXorcist.formatDebugLogMessage("PathHintComponent: Invalid key-value pair: \(pair)", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                }
            }
        }
        if parsedCriteria.isEmpty && !pathSegment.isEmpty {
            if isDebugLoggingEnabled && !axorcJsonLogEnabled {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage("PathHintComponent: Path segment \"\(pathSegment)\" parsed into empty criteria.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }
        self.criteria = parsedCriteria
        if isDebugLoggingEnabled && !axorcJsonLogEnabled {
            currentDebugLogs.append(AXorcist.formatDebugLogMessage("PathHintComponent initialized with criteria: \(self.criteria) from segment: \(pathSegment)", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
        }
    }

    // Convenience initializer if criteria is already a dictionary
    init(criteria: [String: String]) {
        self.criteria = criteria
    }

    func matches(element: Element, isDebugLoggingEnabled: Bool, axorcJsonLogEnabled: Bool, currentDebugLogs: inout [String]) -> Bool {
        // Pass axorcJsonLogEnabled to criteriaMatch
        return criteriaMatch(element: element, criteria: self.criteria, isDebugLoggingEnabled: isDebugLoggingEnabled, axorcJsonLogEnabled: axorcJsonLogEnabled, currentDebugLogs: &currentDebugLogs)
    }
}

// MARK: - Criteria Matching Helper
@MainActor
func criteriaMatch(element: Element, criteria: [String: String]?, isDebugLoggingEnabled: Bool, axorcJsonLogEnabled: Bool, currentDebugLogs: inout [String]) -> Bool {
    guard let criteria = criteria, !criteria.isEmpty else {
        return true // No criteria means an automatic match
    }

    func cLog(_ message: String) {
        // Use the passed-in axorcJsonLogEnabled parameter
        if !axorcJsonLogEnabled && isDebugLoggingEnabled {
            currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
        }
    }
    var tempNilLogs: [String] = [] // For briefDescription calls that don't need to pollute main logs

    for (key, expectedValue) in criteria {
        // Handle wildcard for role if specified
        if key == AXAttributeNames.kAXRoleAttribute && expectedValue == "*" { continue }

        var attributeValueCFType: CFTypeRef?
        // Directly use underlyingElement for AX API calls
        let error = AXUIElementCopyAttributeValue(element.underlyingElement, key as CFString, &attributeValueCFType)

        guard error == .success, let actualValueCF = attributeValueCFType else {
            cLog("Attribute \(key) not found or error \(error.rawValue) on element \(element.briefDescription(option: .default, isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)). No match.")
            return false
        }

        // Use ValueUnwrapper to convert CFTypeRef to a Swift type
        // Assuming ValueUnwrapper.unwrap is available and correctly handles logging parameters
        let actualValueSwift: Any? = ValueUnwrapper.unwrap(actualValueCF, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
        let actualValueString = String(describing: actualValueSwift ?? "nil_after_unwrap")

        // Perform case-insensitive comparison or exact match
        if !(actualValueString.localizedCaseInsensitiveContains(expectedValue) || actualValueString == expectedValue) {
            cLog("Attribute '\(key)' mismatch: Expected '\(expectedValue)', Got '\(actualValueString)'. Element: \(element.briefDescription(option: .default, isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)). No match.")
            return false
        }
        cLog("Attribute '\(key)' matched: Expected '\(expectedValue)', Got '\(actualValueString)'.")
    }
    cLog("All criteria matched for element: \(element.briefDescription(option: .default, isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)).")
    return true
}
