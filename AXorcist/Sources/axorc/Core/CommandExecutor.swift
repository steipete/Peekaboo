// CommandExecutor.swift - Executes AXORC commands

import AXorcistLib
import Foundation

// TEMPORARY TEST STRUCT - REMOVED
// struct SimpleTestResponse: Codable {
//     var message: String
//     var logs: [String]?
// }

struct CommandExecutor {

    static func execute(
        command: CommandEnvelope,
        axorcist: AXorcist,
        debug: Bool
    ) async -> String {

        var localDebugLogs: [String] = []
        // Determine the effective debug logging state
        let effectiveDebugLogging = command.debug_logging ?? debug

        if effectiveDebugLogging { localDebugLogs.append("Executing command: \(command.command) (ID: \(command.command_id)), effectiveDebug: \(effectiveDebugLogging), cliDebug: \(debug), jsonDebug: \(String(describing: command.debug_logging))") }

        let ax = axorcist // Use the passed-in instance

        switch command.command {
        case .performAction:
            guard let actionName = command.action_name else {
                let error = "Missing action_name for performAction"
                localDebugLogs.append(error)
                return encodeToJson(QueryResponse(
                    success: false,
                    commandId: command.command_id,
                    command: command.command.rawValue,
                    error: error,
                    debugLogs: effectiveDebugLogging ? localDebugLogs : nil
                )) ?? "{\"error\": \"Encoding error response failed\"}"
            }
            let handlerResponse = await Self.executePerformAction(
                command: command,
                ax: ax,
                effectiveDebugLogging: effectiveDebugLogging,
                localDebugLogs: &localDebugLogs,
                actionName: actionName
            )
            return Self.finalizeAndEncodeResponse(
                commandId: command.command_id,
                commandType: command.command.rawValue,
                handlerResponse: handlerResponse,
                localDebugLogs: localDebugLogs,
                effectiveDebugLogging: effectiveDebugLogging
            )

        case .getFocusedElement:
            let handlerResponse = await Self.executeGetFocusedElement(
                command: command,
                ax: ax,
                effectiveDebugLogging: effectiveDebugLogging,
                localDebugLogs: &localDebugLogs
            )
            return Self.finalizeAndEncodeResponse(
                commandId: command.command_id,
                commandType: command.command.rawValue,
                handlerResponse: handlerResponse,
                localDebugLogs: localDebugLogs,
                effectiveDebugLogging: effectiveDebugLogging
            )

        case .getAttributes:
            let handlerResponse = await Self.executeGetAttributes(
                command: command,
                ax: ax,
                effectiveDebugLogging: effectiveDebugLogging,
                localDebugLogs: &localDebugLogs
            )
            return Self.finalizeAndEncodeResponse(
                commandId: command.command_id,
                commandType: command.command.rawValue,
                handlerResponse: handlerResponse,
                localDebugLogs: localDebugLogs,
                effectiveDebugLogging: effectiveDebugLogging
            )

        case .query:
            let handlerResponse = await Self.executeQuery(
                command: command,
                ax: ax,
                effectiveDebugLogging: effectiveDebugLogging,
                localDebugLogs: &localDebugLogs
            )
            return Self.finalizeAndEncodeResponse(
                commandId: command.command_id,
                commandType: command.command.rawValue,
                handlerResponse: handlerResponse,
                localDebugLogs: localDebugLogs,
                effectiveDebugLogging: effectiveDebugLogging
            )

        case .describeElement:
            let handlerResponse = await Self.executeDescribeElement(
                command: command,
                ax: ax,
                effectiveDebugLogging: effectiveDebugLogging,
                localDebugLogs: &localDebugLogs
            )
            return Self.finalizeAndEncodeResponse(
                commandId: command.command_id,
                commandType: command.command.rawValue,
                handlerResponse: handlerResponse,
                localDebugLogs: localDebugLogs,
                effectiveDebugLogging: effectiveDebugLogging
            )

        case .extractText:
            let handlerResponse = await Self.executeExtractText(
                command: command,
                ax: ax,
                effectiveDebugLogging: effectiveDebugLogging,
                localDebugLogs: &localDebugLogs
            )
            return Self.finalizeAndEncodeResponse(
                commandId: command.command_id,
                commandType: command.command.rawValue,
                handlerResponse: handlerResponse,
                localDebugLogs: localDebugLogs,
                effectiveDebugLogging: effectiveDebugLogging
            )

        case .collectAll:
            let jsonStringResult = await ax.handleCollectAll(
                for: command.application,
                locator: command.locator,
                pathHint: command.path_hint,
                maxDepth: command.max_elements,
                requestedAttributes: command.attributes,
                outputFormat: command.output_format,
                commandId: command.command_id,
                isDebugLoggingEnabled: effectiveDebugLogging,
                currentDebugLogs: localDebugLogs
            )
            return jsonStringResult

        case .batch:
            let batchResponse = await Self.executeBatch(
                command: command,
                ax: ax,
                effectiveDebugLogging: effectiveDebugLogging,
                localDebugLogs: &localDebugLogs
            )
            return encodeToJson(batchResponse) ?? "{\"error\": \"Encoding batch response failed\"}"

        case .ping:
            if effectiveDebugLogging { localDebugLogs.append("Ping command received. Responding with pong.") }
            let pingHandlerResponse = HandlerResponse(
                data: nil,
                error: nil,
                debug_logs: nil
            )
            return Self.finalizeAndEncodeResponse(
                commandId: command.command_id,
                commandType: command.command.rawValue,
                handlerResponse: pingHandlerResponse,
                localDebugLogs: localDebugLogs,
                effectiveDebugLogging: effectiveDebugLogging
            )
        }
    }

    // MARK: - Command Execution Functions

    private static func executePerformAction(
        command: CommandEnvelope,
        ax: AXorcist,
        effectiveDebugLogging: Bool,
        localDebugLogs: inout [String],
        actionName: String
    ) async -> HandlerResponse {
        // Locator is now optional for this path, AXorcist.handlePerformAction will use path_hint if locator is nil
        return await ax.handlePerformAction(
            for: command.application,
            locator: command.locator, // This can be nil
            pathHint: command.path_hint,
            actionName: actionName,
            actionValue: command.action_value,
            maxDepth: command.max_elements,
            isDebugLoggingEnabled: effectiveDebugLogging,
            currentDebugLogs: &localDebugLogs
        )
    }

    private static func executeGetFocusedElement(
        command: CommandEnvelope,
        ax: AXorcist,
        effectiveDebugLogging: Bool,
        localDebugLogs: inout [String]
    ) async -> HandlerResponse {
        return await ax.handleGetFocusedElement(
            for: command.application,
            requestedAttributes: command.attributes,
            isDebugLoggingEnabled: effectiveDebugLogging,
            currentDebugLogs: &localDebugLogs
        )
    }

    private static func executeGetAttributes(
        command: CommandEnvelope,
        ax: AXorcist,
        effectiveDebugLogging: Bool,
        localDebugLogs: inout [String]
    ) async -> HandlerResponse {
        guard let locator = command.locator else {
            let error = "Missing locator for getAttributes"
            localDebugLogs.append(error)
            return HandlerResponse(
                data: nil,
                error: error,
                debug_logs: nil
            )
        }
        return await ax.handleGetAttributes(
            for: command.application,
            locator: locator,
            requestedAttributes: command.attributes,
            pathHint: command.path_hint,
            maxDepth: command.max_elements,
            outputFormat: command.output_format,
            isDebugLoggingEnabled: effectiveDebugLogging,
            currentDebugLogs: &localDebugLogs
        )
    }

    private static func executeQuery(
        command: CommandEnvelope,
        ax: AXorcist,
        effectiveDebugLogging: Bool,
        localDebugLogs: inout [String]
    ) async -> HandlerResponse {
        guard let locator = command.locator else {
            let error = "Missing locator for query"
            localDebugLogs.append(error)
            return HandlerResponse(
                data: nil,
                error: error,
                debug_logs: nil
            )
        }
        return await ax.handleQuery(
            for: command.application,
            locator: locator,
            pathHint: command.path_hint,
            maxDepth: command.max_elements,
            requestedAttributes: command.attributes,
            outputFormat: command.output_format,
            isDebugLoggingEnabled: effectiveDebugLogging,
            currentDebugLogs: &localDebugLogs
        )
    }

    private static func executeDescribeElement(
        command: CommandEnvelope,
        ax: AXorcist,
        effectiveDebugLogging: Bool,
        localDebugLogs: inout [String]
    ) async -> HandlerResponse {
        guard let locator = command.locator else {
            let error = "Missing locator for describeElement"
            localDebugLogs.append(error)
            return HandlerResponse(
                data: nil,
                error: error,
                debug_logs: nil
            )
        }
        return await ax.handleDescribeElement(
            for: command.application,
            locator: locator,
            pathHint: command.path_hint,
            maxDepth: command.max_elements,
            requestedAttributes: command.attributes,
            outputFormat: command.output_format,
            isDebugLoggingEnabled: effectiveDebugLogging,
            currentDebugLogs: &localDebugLogs
        )
    }

    private static func executeExtractText(
        command: CommandEnvelope,
        ax: AXorcist,
        effectiveDebugLogging: Bool,
        localDebugLogs: inout [String]
    ) async -> HandlerResponse {
        guard let locator = command.locator else {
            let error = "Missing locator for extractText"
            localDebugLogs.append(error)
            return HandlerResponse(
                data: nil,
                error: error,
                debug_logs: nil
            )
        }
        return await ax.handleExtractText(
            for: command.application,
            locator: locator,
            pathHint: command.path_hint,
            isDebugLoggingEnabled: effectiveDebugLogging,
            currentDebugLogs: &localDebugLogs
        )
    }

    private static func executeBatch(
        command: CommandEnvelope,
        ax: AXorcist,
        effectiveDebugLogging: Bool,
        localDebugLogs: inout [String]
    ) async -> BatchResponse {
        guard let subCommands = command.sub_commands else {
            let error = "Missing sub_commands for batch command"
            localDebugLogs.append(error)
            return BatchResponse(
                command_id: command.command_id,
                success: false,
                results: [],
                error: error,
                debug_logs: effectiveDebugLogging ? localDebugLogs : nil
            )
        }

        var batchDebugLogs = localDebugLogs
        let batchResults: [HandlerResponse] = await ax.handleBatchCommands(
            batchCommandID: command.command_id,
            subCommands: subCommands,
            isDebugLoggingEnabled: effectiveDebugLogging,
            currentDebugLogs: &batchDebugLogs
        )

        let overallSuccess = batchResults.allSatisfy { $0.error == nil }
        return BatchResponse(
            command_id: command.command_id,
            success: overallSuccess,
            results: batchResults,
            error: nil,
            debug_logs: effectiveDebugLogging ? batchDebugLogs : nil
        )
    }

    // MARK: - Helper Functions

    private static func finalizeAndEncodeResponse(
        commandId: String,
        commandType: String,
        handlerResponse: HandlerResponse,
        localDebugLogs: [String],
        effectiveDebugLogging: Bool
    ) -> String {
        // Combine debug logs if debug logging is enabled
        var combinedDebugLogs: [String]?
        if effectiveDebugLogging {
            combinedDebugLogs = localDebugLogs
            if let handlerDebugLogs = handlerResponse.debug_logs {
                combinedDebugLogs?.append(contentsOf: handlerDebugLogs)
            }
        }

        // Create QueryResponse
        let queryResponse = QueryResponse(
            command_id: commandId,
            success: handlerResponse.error == nil,
            command: commandType,
            handlerResponse: handlerResponse,
            debug_logs: combinedDebugLogs
        )

        // Encode to JSON and return
        return encodeToJson(queryResponse) ?? "{\"error\": \"Encoding \(commandType) response failed\"}"
    }

    private static func encodeToJson<T: Codable>(_ object: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(object)
            return String(data: data, encoding: .utf8)
        } catch {
            // PRINT THE ERROR TO STDERR
            let errorDescription = "JSON ENCODING ERROR: \(error.localizedDescription). Details: \(error)"
            FileHandle.standardError.write(errorDescription.data(using: .utf8)!)
            return nil
        }
    }
}
