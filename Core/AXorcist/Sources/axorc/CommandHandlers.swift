// CommandHandlers.swift - Command-specific handler functions

import AppKit
import AXorcist
import Foundation

// MARK: - Command Handlers

@MainActor
func handlePerformActionCommand(command: CommandEnvelope, axorcist: AXorcist, debugCLI: Bool) -> String {
    guard command.actionName != nil else {
        let errorResponse = HandlerResponse(data: nil, error: "performAction requires actionName")
        return finalizeAndEncodeResponse(
            commandId: command.commandId,
            commandType: command.command.rawValue,
            handlerResponse: errorResponse,
            debugCLI: debugCLI,
            commandDebugLogging: command.debugLogging
        )
    }

    return handleSimpleCommand(command: command, axorcist: axorcist, debugCLI: debugCLI, executor: executePerformAction)
}

@MainActor
func handleBatchCommand(command: CommandEnvelope, axorcist: AXorcist, debugCLI: Bool) -> String {
    guard let batchCmd = command.command.toAXCommand(commandEnvelope: command) else {
        let errorResponse = BatchQueryResponse(
            commandId: command.commandId,
            status: "error",
            message: "Failed to create AXCommand for Batch"
        )
        return encodeToJson(errorResponse) ??
            "{\"error\": \"Encoding batch response failed\", \"commandId\": \"\(command.commandId)\"}"
    }

    let axResponse = axorcist.runCommand(AXCommandEnvelope(commandID: command.commandId, command: batchCmd))

    var finalResponseObject = BatchQueryResponse(commandId: command.commandId, status: "pending")
    var logsForResponse: [String]?

    if axResponse.status == "success" {
        if let batchPayload = axResponse.payload?.value as? BatchResponsePayload {
            finalResponseObject = BatchQueryResponse(
                commandId: command.commandId,
                status: "success",
                data: batchPayload.results,
                errors: batchPayload.errors,
                debugLogs: nil
            )
        } else {
            finalResponseObject = BatchQueryResponse(
                commandId: command.commandId,
                status: "error",
                message: "Batch success but payload was not BatchResponsePayload",
                debugLogs: nil
            )
        }
    } else {
        let errorMessage = axResponse.error?.message ?? "Batch operation failed with unknown error."
        if let batchPayload = axResponse.payload?.value as? BatchResponsePayload {
            finalResponseObject = BatchQueryResponse(
                commandId: command.commandId,
                status: "error",
                message: errorMessage,
                data: batchPayload.results,
                errors: batchPayload.errors,
                debugLogs: nil
            )
        } else {
            finalResponseObject = BatchQueryResponse(
                commandId: command.commandId,
                status: "error",
                message: errorMessage,
                debugLogs: nil
            )
        }
    }

    if debugCLI || command.debugLogging {
        logsForResponse = axGetLogsAsStrings()
        finalResponseObject.debugLogs = logsForResponse
    }

    return encodeToJson(finalResponseObject) ??
        "{\"error\": \"Encoding batch response failed\", \"commandId\": \"\(command.commandId)\"}"
}

func handlePingCommand(command: CommandEnvelope, debugCLI: Bool) -> String {
    axDebugLog("Ping command received. Responding with pong.")
    let pingHandlerResponse = HandlerResponse(data: AnyCodable("pong"), error: nil)
    return finalizeAndEncodeResponse(
        commandId: command.commandId,
        commandType: command.command.rawValue,
        handlerResponse: pingHandlerResponse,
        debugCLI: debugCLI,
        commandDebugLogging: command.debugLogging
    )
}

func handleNotImplementedCommand(command: CommandEnvelope, message: String, debugCLI: Bool) -> String {
    let notImplementedResponse = HandlerResponse(data: nil, error: message)
    return finalizeAndEncodeResponse(
        commandId: command.commandId,
        commandType: command.command.rawValue,
        handlerResponse: notImplementedResponse,
        debugCLI: debugCLI,
        commandDebugLogging: command.debugLogging
    )
}

@MainActor
func handleObserveCommand(command: CommandEnvelope, axorcist: AXorcist, debugCLI: Bool) -> String {
    guard let axObserveCommand = command.command.toAXCommand(commandEnvelope: command) else {
        axErrorLog("Failed to convert Observe to AXCommand")
        let errorResponse = HandlerResponse(data: nil, error: "Internal error: Failed to create AXCommand for Observe")
        return finalizeAndEncodeResponse(
            commandId: command.commandId,
            commandType: command.command.rawValue,
            handlerResponse: errorResponse,
            debugCLI: debugCLI,
            commandDebugLogging: command.debugLogging
        )
    }

    let axResponse = axorcist.runCommand(AXCommandEnvelope(commandID: command.commandId, command: axObserveCommand))
    let handlerResponse = HandlerResponse(from: axResponse)

    return finalizeAndEncodeResponse(
        commandId: command.commandId,
        commandType: command.command.rawValue,
        handlerResponse: handlerResponse,
        debugCLI: debugCLI,
        commandDebugLogging: command.debugLogging
    )
}

@MainActor
func handleSimpleCommand(
    command: CommandEnvelope,
    axorcist: AXorcist,
    debugCLI: Bool,
    executor: (CommandEnvelope, AXorcist) -> HandlerResponse
) -> String {
    let handlerResponse = executor(command, axorcist)
    return finalizeAndEncodeResponse(
        commandId: command.commandId,
        commandType: command.command.rawValue,
        handlerResponse: handlerResponse,
        debugCLI: debugCLI,
        commandDebugLogging: command.debugLogging
    )
}
