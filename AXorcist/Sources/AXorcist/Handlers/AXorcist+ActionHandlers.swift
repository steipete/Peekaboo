// AXorcist+ActionHandlers.swift - Action and data operation handlers

import AppKit
import ApplicationServices
import Darwin
import Foundation

// MARK: - Environment Variable Check for JSON Logging
// (Copied from other files - consider a shared utility)
private func getEnvVar(_ name: String) -> String? {
    guard let value = getenv(name) else { return nil }
    return String(cString: value)
}

private let HANDLER_AXORC_JSON_LOG_ENABLED: Bool = {
    let envValue = getEnvVar("AXORC_JSON_LOG")?.lowercased()
    // No fputs here, assuming it's primarily for Swift module debugging
    return envValue == "true"
}()

// MARK: - Action & Data Handlers Extension
extension AXorcist {

    // MARK: - Private Helper Methods

    private func executeStandardAccessibilityAction(
        _ axActionName: CFString,
        on targetElement: Element,
        actionNameForLog: String,
        currentDebugLogs: inout [String]
    ) -> AXError {
        let axStatus = AXUIElementPerformAction(targetElement.underlyingElement, axActionName)
        if axStatus != .success {
            let errorMessage = "[AXorcist.handlePerformAction] Failed to perform \(actionNameForLog) action: \(axErrorToString(axStatus))"
            currentDebugLogs.append(errorMessage)
        }
        return axStatus
    }

    private func executeSetAttributeValueAction(
        attributeName: String,
        value: AnyCodable?,
        on targetElement: Element,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> (errorMessage: String?, axStatus: AXError) {

        func dLog(_ message: String) {
            if isDebugLoggingEnabled {
                currentDebugLogs.append(message)
            }
        }

        if attributeName.hasPrefix("AX") {
            let axStatus = AXUIElementPerformAction(targetElement.underlyingElement, attributeName as CFString)
            if axStatus != .success {
                let errorMessage = "[AXorcist.handlePerformAction] Failed to perform action '\(attributeName)': \(axErrorToString(axStatus))"
                return (errorMessage, axStatus)
            }
            return (nil, axStatus)
        } else {
            guard let actionValue = value else {
                let errorMessage = "[AXorcist.handlePerformAction] Attribute action '\(attributeName)' requires an action_value, but none was provided."
                return (errorMessage, .invalidUIElement)
            }

            var cfValue: CFTypeRef?
            switch actionValue.value {
            case let stringValue as String:
                cfValue = stringValue as CFString
            case let boolValue as Bool:
                cfValue = boolValue as CFBoolean
            case let intValue as Int:
                var number = intValue
                cfValue = CFNumberCreate(kCFAllocatorDefault, .intType, &number)
            case let doubleValue as Double:
                var number = doubleValue
                cfValue = CFNumberCreate(kCFAllocatorDefault, .doubleType, &number)
            default:
                if CFGetTypeID(actionValue.value as AnyObject) != 0 {
                    cfValue = actionValue.value as AnyObject
                    dLog("[AXorcist.handlePerformAction] Warning: Attempting to use actionValue of type '\(type(of: actionValue.value))' directly as CFTypeRef for attribute '\(attributeName)'. This might not work as expected.")
                } else {
                    let errorMessage = "[AXorcist.handlePerformAction] Unsupported value type '\(type(of: actionValue.value))' for attribute '\(attributeName)'. Cannot convert to CFTypeRef."
                    dLog(errorMessage)
                    return (errorMessage, .invalidUIElement)
                }
            }

            guard let finalCFValue = cfValue else {
                let errorMessage = "[AXorcist.handlePerformAction] Failed to convert value for attribute '\(attributeName)' to a CoreFoundation type."
                return (errorMessage, .invalidUIElement)
            }

            let axStatus = AXUIElementSetAttributeValue(targetElement.underlyingElement, attributeName as CFString, finalCFValue)
            if axStatus != .success {
                let errorMessage = "[AXorcist.handlePerformAction] Failed to set attribute '\(attributeName)' to value '\(String(describing: actionValue.value))': \(axErrorToString(axStatus))"
                return (errorMessage, axStatus)
            }

            return (nil, axStatus)
        }
    }

    @MainActor
    public func handlePerformAction(
        for appIdentifierOrNil: String? = nil,
        locator: Locator?,
        pathHint: [String]? = nil,
        actionName: String,
        actionValue: AnyCodable?,
        maxDepth: Int? = nil,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) async -> HandlerResponse {

        func dLog(_ message: String) {
            if isDebugLoggingEnabled {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: appIdentifierOrNil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }

        let appIdentifier = appIdentifierOrNil ?? focusedAppKeyValue
        dLog("[AXorcist.handlePerformAction] Handling for app: \(appIdentifier), action: \(actionName)")

        let targetElementResult = await self.findTargetElement(
            for: appIdentifierOrNil,
            locator: locator,
            pathHint: pathHint,
            isRootedAtApp: true,
            baseElement: nil,
            maxDepthForSearch: maxDepth,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        let targetElement: Element
        switch targetElementResult {
        case .success(let element):
            targetElement = element
        case .failure(let error):
            return HandlerResponse(data: nil, error: error.message, debug_logs: error.logs ?? currentDebugLogs)
        }

        dLog("[AXorcist.handlePerformAction] Element for action: \(targetElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))")
        if let actionValue = actionValue {
            let valueDescription = String(describing: actionValue.value)
            dLog("[AXorcist.handlePerformAction] Performing action '\(actionName)' with value: \(valueDescription)")
        } else {
            dLog("[AXorcist.handlePerformAction] Performing action '\(actionName)'")
        }

        var errorMessage: String?
        var axStatus: AXError = .success

        switch actionName.lowercased() {
        case "press":
            axStatus = self.executeStandardAccessibilityAction(
                AXActionNames.kAXPressAction as CFString,
                on: targetElement,
                actionNameForLog: "press",
                currentDebugLogs: &currentDebugLogs
            )
            if axStatus != .success {
                errorMessage = "[AXorcist.handlePerformAction] Failed to perform press action: \(axErrorToString(axStatus))"
            }
        case "increment":
            axStatus = self.executeStandardAccessibilityAction(
                AXActionNames.kAXIncrementAction as CFString,
                on: targetElement,
                actionNameForLog: "increment",
                currentDebugLogs: &currentDebugLogs
            )
            if axStatus != .success {
                errorMessage = "[AXorcist.handlePerformAction] Failed to perform increment action: \(axErrorToString(axStatus))"
            }
        case "decrement":
            axStatus = self.executeStandardAccessibilityAction(
                AXActionNames.kAXDecrementAction as CFString,
                on: targetElement,
                actionNameForLog: "decrement",
                currentDebugLogs: &currentDebugLogs
            )
            if axStatus != .success {
                errorMessage = "[AXorcist.handlePerformAction] Failed to perform decrement action: \(axErrorToString(axStatus))"
            }
        case "showmenu":
            axStatus = self.executeStandardAccessibilityAction(
                AXActionNames.kAXShowMenuAction as CFString,
                on: targetElement,
                actionNameForLog: "showmenu",
                currentDebugLogs: &currentDebugLogs
            )
            if axStatus != .success {
                errorMessage = "[AXorcist.handlePerformAction] Failed to perform showmenu action: \(axErrorToString(axStatus))"
            }
        case "pick":
            axStatus = self.executeStandardAccessibilityAction(
                AXActionNames.kAXPickAction as CFString,
                on: targetElement,
                actionNameForLog: "pick",
                currentDebugLogs: &currentDebugLogs
            )
            if axStatus != .success {
                errorMessage = "[AXorcist.handlePerformAction] Failed to perform pick action: \(axErrorToString(axStatus))"
            }
        case "cancel":
            axStatus = self.executeStandardAccessibilityAction(
                AXActionNames.kAXCancelAction as CFString,
                on: targetElement,
                actionNameForLog: "cancel",
                currentDebugLogs: &currentDebugLogs
            )
            if axStatus != .success {
                errorMessage = "[AXorcist.handlePerformAction] Failed to perform cancel action: \(axErrorToString(axStatus))"
            }
        default:
            let result = self.executeSetAttributeValueAction(
                attributeName: actionName,
                value: actionValue,
                on: targetElement,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
            errorMessage = result.errorMessage
            axStatus = result.axStatus
        }

        if let currentErrorMessage = errorMessage {
            currentDebugLogs.append(currentErrorMessage)
            return HandlerResponse(data: nil, error: currentErrorMessage, debug_logs: currentDebugLogs)
        }

        dLog("[AXorcist.handlePerformAction] Action '\(actionName)' performed successfully.")
        return HandlerResponse(data: nil, error: nil, debug_logs: currentDebugLogs)
    }

    @MainActor
    public func handleExtractText(
        for appIdentifierOrNil: String? = nil,
        locator: Locator?,
        pathHint: [String]? = nil,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) async -> HandlerResponse {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: appIdentifierOrNil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }

        let appIdentifier = appIdentifierOrNil ?? focusedAppKeyValue
        dLog("[handleExtractText] Starting text extraction for app: \(appIdentifier)")

        let targetElementResult = await self.findTargetElement(
            for: appIdentifierOrNil,
            locator: locator,
            pathHint: pathHint,
            isRootedAtApp: true,
            baseElement: nil,
            maxDepthForSearch: nil,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        let targetElementForExtract: Element
        let appElement: Element
        switch targetElementResult {
        case .success(let element):
            targetElementForExtract = element
            // We need the app element for path generation, so get it separately
            guard let appEl = applicationElement(
                for: appIdentifier,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            ) else {
                let errorMessage = "[handleExtractText] Failed to get application element for path generation: \(appIdentifier)"
                currentDebugLogs.append(errorMessage)
                return HandlerResponse(data: nil, error: errorMessage, debug_logs: currentDebugLogs)
            }
            appElement = appEl
        case .failure(let error):
            return HandlerResponse(data: nil, error: error.message, debug_logs: error.logs ?? currentDebugLogs)
        }

        dLog("[handleExtractText] Target element found: \(targetElementForExtract.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)), attempting to extract text")
        var attributes: [String: AnyCodable] = [:]
        var extractedAnyText = false

        if let valueCF = targetElementForExtract.rawAttributeValue(named: AXAttributeNames.kAXValueAttribute as String, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs) {
            if CFGetTypeID(valueCF) == CFStringGetTypeID() {
                let extractedValueText = valueCF as! String
                if !extractedValueText.isEmpty {
                    attributes["extractedValue"] = AnyCodable(extractedValueText)
                    extractedAnyText = true
                    dLog("[handleExtractText] Extracted text from AXValueAttribute (length: \(extractedValueText.count)): \(extractedValueText.prefix(80))...")
                } else {
                    dLog("[handleExtractText] AXValueAttribute was empty or not a string.")
                }
            } else {
                dLog("[handleExtractText] AXValueAttribute was present but not a CFString. TypeID: \(CFGetTypeID(valueCF))")
            }
        } else {
            dLog("[handleExtractText] AXValueAttribute not found or nil.")
        }

        if let selectedValueCF = targetElementForExtract.rawAttributeValue(named: AXAttributeNames.kAXSelectedTextAttribute as String, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs) {
            if CFGetTypeID(selectedValueCF) == CFStringGetTypeID() {
                let extractedSelectedText = selectedValueCF as! String
                if !extractedSelectedText.isEmpty {
                    attributes["extractedSelectedText"] = AnyCodable(extractedSelectedText)
                    extractedAnyText = true
                    dLog("[handleExtractText] Extracted selected text from AXSelectedTextAttribute (length: \(extractedSelectedText.count)): \(extractedSelectedText.prefix(80))...")
                } else {
                    dLog("[handleExtractText] AXSelectedTextAttribute was empty or not a string.")
                }
            } else {
                dLog("[handleExtractText] AXSelectedTextAttribute was present but not a CFString. TypeID: \(CFGetTypeID(selectedValueCF))")
            }
        } else {
            dLog("[handleExtractText] AXSelectedTextAttribute not found or nil.")
        }

        if !extractedAnyText {
            dLog("[handleExtractText] No text could be extracted from AXValue or AXSelectedText for element.")
        }

        let pathArray = targetElementForExtract.generatePathArray(upTo: appElement, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
        let axElementToReturn = AXElement(attributes: attributes, path: pathArray)
        return HandlerResponse(data: axElementToReturn, error: nil, debug_logs: currentDebugLogs)
    }
}
