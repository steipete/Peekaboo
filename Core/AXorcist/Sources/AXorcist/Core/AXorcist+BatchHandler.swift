import Foundation

/// Extension providing batch command processing for AXorcist.
///
/// This extension handles:
/// - Batch execution of multiple accessibility commands
/// - Sequential processing with error handling
/// - Result aggregation and response compilation
/// - Error collection and reporting across batch operations
/// - Performance optimization for multiple operations
@MainActor
extension AXorcist {
    public func handleBatchCommands(command: AXBatchCommand) -> AXResponse {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandleBatch: Received \(command.commands.count) sub-commands."
        ))
        var results: [AXResponse] = []
        var overallSuccess = true
        var errorMessages: [String] = []

        for (index, subCommandEnvelope) in command.commands.enumerated() {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "HandleBatch: Processing sub-command \(index + 1)/\(command.commands.count): " +
                    "ID '\(subCommandEnvelope.commandID)', Type: \(subCommandEnvelope.command.type)"
            ))

            let response = processSingleBatchCommand(subCommandEnvelope.command)
            results.append(response)

            if response.status != "success" {
                overallSuccess = false
                let errorDetail = response.error?
                    .message ?? "Unknown error in sub-command \(subCommandEnvelope.commandID)"
                errorMessages
                    .append(
                        "Sub-command \(subCommandEnvelope.commandID) ('\(subCommandEnvelope.command.type)') failed: \(errorDetail)"
                    )
                GlobalAXLogger.shared.log(AXLogEntry(
                    level: .warning,
                    message: "HandleBatch: Sub-command \(subCommandEnvelope.commandID) failed: \(errorDetail)"
                ))
            }
        }

        if overallSuccess {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "HandleBatch: All \(command.commands.count) sub-commands succeeded."
            ))
            let successfulPayloads = results.map(\.payload)
            return .successResponse(payload: AnyCodable(BatchResponsePayload(results: successfulPayloads, errors: nil)))
        } else {
            let combinedErrorMessage =
                "HandleBatch: One or more sub-commands failed. Errors: \(errorMessages.joined(separator: "; "))"
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: combinedErrorMessage))
            return .errorResponse(message: combinedErrorMessage, code: .batchOperationFailed)
        }
    }

    private func processSingleBatchCommand(_ command: AXCommand) -> AXResponse {
        switch command {
        case let .query(queryCommand):
            return handleQuery(command: queryCommand, maxDepth: queryCommand.maxDepthForSearch)
        case let .performAction(actionCommand):
            return handlePerformAction(command: actionCommand)
        case let .getAttributes(getAttributesCommand):
            return handleGetAttributes(command: getAttributesCommand)
        case let .describeElement(describeCommand):
            return handleDescribeElement(command: describeCommand)
        case let .extractText(extractTextCommand):
            return handleExtractText(command: extractTextCommand)
        case let .setFocusedValue(setFocusedValueCommand):
            return handleSetFocusedValue(command: setFocusedValueCommand)
        case let .getElementAtPoint(getElementAtPointCommand):
            return handleGetElementAtPoint(command: getElementAtPointCommand)
        case let .getFocusedElement(getFocusedElementCommand):
            return handleGetFocusedElement(command: getFocusedElementCommand)
        case let .observe(observeCommand):
            GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: "BatchProc: Processing Observe command."))
            return handleObserve(command: observeCommand)
        case let .collectAll(collectAllCommand):
            return handleCollectAll(command: collectAllCommand)
        case .batch:
            return .errorResponse(
                message: "Nested batch commands are not supported within a single batch operation.",
                code: .invalidCommand
            )
        }
    }
}
