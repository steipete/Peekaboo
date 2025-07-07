// AXorcist+BatchHandler.swift - Batch processing operations

import AppKit
import ApplicationServices
import Foundation

// MARK: - Batch Processing Handler Extension
extension AXorcist {

    @MainActor
    public func handleBatchCommands(
        batchCommandID: String, // The ID of the overall batch command
        subCommands: [CommandEnvelope], // The array of sub-commands to process
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) async -> [HandlerResponse] {
        // Local debug logging function
        func dLog(_ message: String, subCommandID: String? = nil) {
            if isDebugLoggingEnabled {
                let prefix = subCommandID != nil ? "[AXorcist.handleBatchCommands][SubCmdID: \(subCommandID!)]" :
                    "[AXorcist.handleBatchCommands][BatchID: \(batchCommandID)]"
                currentDebugLogs.append("\(prefix) \(message)")
            }
        }

        dLog("Starting batch processing with \(subCommands.count) sub-commands.")

        var batchResults: [HandlerResponse] = []

        for subCommandEnvelope in subCommands {
            let subCmdID = subCommandEnvelope.command_id
            // Create a temporary log array for this specific sub-command to pass to handlers if needed,
            // or decide if currentDebugLogs should be directly mutated by sub-handlers and reflect cumulative logs.
            // For simplicity here, let's assume sub-handlers append to the main currentDebugLogs.
            dLog("Processing sub-command: \(subCmdID), type: \(subCommandEnvelope.command)", subCommandID: subCmdID)

            var subCommandResponse: HandlerResponse

            switch subCommandEnvelope.command {
            case .getFocusedElement:
                subCommandResponse = self.handleGetFocusedElement(
                    for: subCommandEnvelope.application,
                    requestedAttributes: subCommandEnvelope.attributes,
                    isDebugLoggingEnabled: isDebugLoggingEnabled,
                    currentDebugLogs: &currentDebugLogs // Pass the main log array
                )

            case .getAttributes:
                guard let locator = subCommandEnvelope.locator else {
                    let errorMsg = "Locator missing for getAttributes in batch (sub-command ID: \(subCmdID))"
                    dLog(errorMsg, subCommandID: subCmdID)
                    subCommandResponse = HandlerResponse(
                        data: nil,
                        error: errorMsg,
                        debug_logs: nil
                    ) // Keep debug_logs nil for specific error, main logs will have the dLog entry
                    break
                }
                subCommandResponse = await self.handleGetAttributes(
                    for: subCommandEnvelope.application,
                    locator: locator,
                    requestedAttributes: subCommandEnvelope.attributes,
                    pathHint: subCommandEnvelope.path_hint,
                    maxDepth: subCommandEnvelope.max_elements,
                    outputFormat: subCommandEnvelope.output_format,
                    isDebugLoggingEnabled: isDebugLoggingEnabled,
                    currentDebugLogs: &currentDebugLogs
                )

            case .query:
                guard let locator = subCommandEnvelope.locator else {
                    let errorMsg = "Locator missing for query in batch (sub-command ID: \(subCmdID))"
                    dLog(errorMsg, subCommandID: subCmdID)
                    subCommandResponse = HandlerResponse(data: nil, error: errorMsg, debug_logs: nil)
                    break
                }
                subCommandResponse = await self.handleQuery(
                    for: subCommandEnvelope.application,
                    locator: locator,
                    pathHint: subCommandEnvelope.path_hint,
                    maxDepth: subCommandEnvelope.max_elements,
                    requestedAttributes: subCommandEnvelope.attributes,
                    outputFormat: subCommandEnvelope.output_format,
                    isDebugLoggingEnabled: isDebugLoggingEnabled,
                    currentDebugLogs: &currentDebugLogs
                )

            case .describeElement:
                guard let locator = subCommandEnvelope.locator else {
                    let errorMsg = "Locator missing for describeElement in batch (sub-command ID: \(subCmdID))"
                    dLog(errorMsg, subCommandID: subCmdID)
                    subCommandResponse = HandlerResponse(data: nil, error: errorMsg, debug_logs: nil)
                    break
                }
                subCommandResponse = await self.handleDescribeElement(
                    for: subCommandEnvelope.application,
                    locator: locator,
                    pathHint: subCommandEnvelope.path_hint,
                    maxDepth: subCommandEnvelope.max_elements,
                    requestedAttributes: subCommandEnvelope.attributes,
                    outputFormat: subCommandEnvelope.output_format,
                    isDebugLoggingEnabled: isDebugLoggingEnabled,
                    currentDebugLogs: &currentDebugLogs
                )

            case .performAction:
                // Check if either locator or path_hint is provided
                let hasLocator = subCommandEnvelope.locator != nil
                let hasPathHint = subCommandEnvelope.path_hint != nil && !(subCommandEnvelope.path_hint?.isEmpty ?? true)

                guard hasLocator || hasPathHint else {
                    let errorMsg = "Locator or path_hint missing for performAction in batch (sub-command ID: \(subCmdID))"
                    dLog(errorMsg, subCommandID: subCmdID)
                    subCommandResponse = HandlerResponse(data: nil, error: errorMsg, debug_logs: nil)
                    break
                }

                guard let actionName = subCommandEnvelope.action_name else {
                    let errorMsg = "Action name missing for performAction in batch (sub-command ID: \(subCmdID))"
                    dLog(errorMsg, subCommandID: subCmdID)
                    subCommandResponse = HandlerResponse(data: nil, error: errorMsg, debug_logs: nil)
                    break
                }

                // If only path_hint is provided, locator will be nil, which is fine for handlePerformAction.
                // If only locator is provided, pathHint will be nil or empty, also fine.
                // If both, handlePerformAction can use pathHint as root_element_path_hint for the locator.
                subCommandResponse = await self.handlePerformAction(
                    for: subCommandEnvelope.application,
                    locator: subCommandEnvelope.locator, // Pass along, might be nil
                    pathHint: subCommandEnvelope.path_hint, // Pass along, might be nil or empty
                    actionName: actionName,
                    actionValue: subCommandEnvelope.action_value,
                    maxDepth: subCommandEnvelope.max_elements,
                    isDebugLoggingEnabled: isDebugLoggingEnabled,
                    currentDebugLogs: &currentDebugLogs
                )

            case .extractText:
                guard let locator = subCommandEnvelope.locator else {
                    let errorMsg = "Locator missing for extractText in batch (sub-command ID: \(subCmdID))"
                    dLog(errorMsg, subCommandID: subCmdID)
                    subCommandResponse = HandlerResponse(data: nil, error: errorMsg, debug_logs: nil)
                    break
                }
                subCommandResponse = await self.handleExtractText(
                    for: subCommandEnvelope.application,
                    locator: locator,
                    pathHint: subCommandEnvelope.path_hint,
                    isDebugLoggingEnabled: isDebugLoggingEnabled,
                    currentDebugLogs: &currentDebugLogs
                )

            case .ping:
                let pingMsg = "Ping command handled within batch (sub-command ID: \(subCmdID))"
                dLog(pingMsg, subCommandID: subCmdID)
                // For ping, the handlerResponse itself won't carry much data from AXorcist,
                // but it should indicate success and carry the logs up to this point for this sub-command.
                subCommandResponse = HandlerResponse(
                    data: nil,
                    error: nil,
                    debug_logs: isDebugLoggingEnabled ? currentDebugLogs : nil
                )

            // .batch command cannot be nested. .collectAll is also not handled by AXorcist lib directly.
            case .collectAll, .batch:
                let errorMsg =
                    "Command type '\(subCommandEnvelope.command)' not supported within batch execution by AXorcist (sub-command ID: \(subCmdID))"
                dLog(errorMsg, subCommandID: subCmdID)
                subCommandResponse = HandlerResponse(data: nil, error: errorMsg, debug_logs: nil)

            // default case for any command types that might be added to CommandType enum
            // but not handled by this switch statement within handleBatchCommands.
            // This is distinct from commands axorc itself might handle outside of AXorcist library.
            // @unknown default: // This would be better if Swift enums allowed it easily here for non-frozen enums from other modules.
            // Since CommandType is in axorc, this default captures any CommandType case not explicitly handled above.
            @unknown default:
                let errorMsg =
                    "Unknown or unhandled command type '\(subCommandEnvelope.command)' in batch processing within AXorcist (sub-command ID: \(subCmdID))"
                dLog(errorMsg, subCommandID: subCmdID)
                subCommandResponse = HandlerResponse(data: nil, error: errorMsg, debug_logs: nil)
            }
            batchResults.append(subCommandResponse)
        }

        dLog("Completed batch command processing, returning \(batchResults.count) results.")
        return batchResults
    }
}
