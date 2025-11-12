// CommandExecutor.swift - Main command executor that coordinates command processing

import AppKit // For NSRunningApplication
import AXorcist
import Foundation

@MainActor
struct CommandExecutor {
    // MARK: Internal

    @MainActor
    static func execute(
        command: CommandEnvelope,
        axorcist: AXorcist,
        debugCLI: Bool // This is from the --debug CLI flag
    ) -> String {
        // The main AXORCCommand.run() now sets the global logging based on --debug.
        // CommandExecutor.setupLogging can adjust detail level if command.debugLogging is true.
        let previousDetailLevel = setupDetailLevelForCommand(
            commandDebugLogging: command.debugLogging,
            cliDebug: debugCLI
        )

        defer {
            // Restore only the detail level if it was changed.
            if let prevLevel = previousDetailLevel {
                GlobalAXLogger.shared.detailLevel = prevLevel
            }
        }

        axDebugLog(
            "Executing command: \(command.command) (ID: \(command.commandId)), "
                + "cmdDebug: \(command.debugLogging), cliDebug: \(debugCLI)"
        )

        let responseString = processCommand(command: command, axorcist: axorcist, debugCLI: debugCLI)

        return responseString
    }

    // MARK: Private

    // Simplified to only adjust detail level based on command specific flag, if CLI debug is on.
    private static func setupDetailLevelForCommand(commandDebugLogging: Bool, cliDebug: Bool) -> AXLogDetailLevel? {
        var previousDetailLevel: AXLogDetailLevel?
        if cliDebug { // Only adjust if CLI debugging is already enabled
            if commandDebugLogging, GlobalAXLogger.shared.detailLevel != .verbose {
                previousDetailLevel = GlobalAXLogger.shared.detailLevel
                GlobalAXLogger.shared.detailLevel = .verbose
                axDebugLog("[CommandExecutor.setupDetailLevel] Upped detail level to verbose for this command.")
            }
        } else {
            // If CLI debug is not on, command.debugLogging by itself does not turn on logging here.
            // AXORCMain is the authority for enabling logging globally via --debug.
            // However, if command.debugLogging is true but CLI is not, we might want to enable JUST for this command?
            // For now, keeping it simple: CLI --debug is master switch.
        }
        return previousDetailLevel
    }

    private typealias DirectCommandHandler = (CommandEnvelope, AXorcist, Bool) -> String
    private typealias SimpleCommandExecutor = (CommandEnvelope, AXorcist) -> HandlerResponse

    private static let simpleExecutors: [CommandType: SimpleCommandExecutor] = [
        .getFocusedElement: executeGetFocusedElement,
        .getAttributes: executeGetAttributes,
        .query: executeQuery,
        .describeElement: executeDescribeElement,
        .extractText: executeExtractText
    ]

    private static let commandHandlers: [CommandType: DirectCommandHandler] = [
        .performAction: handlePerformActionCommand,
        .collectAll: handleCollectAllCommand,
        .getElementAtPoint: handleGetElementAtPointCommand,
        .setFocusedValue: handleSetFocusedValueCommand,
        .ping: { command, _, debugCLI in handlePingCommand(command: command, debugCLI: debugCLI) },
        .batch: handleBatchCommand,
        .observe: handleObserveCommand,
        .stopObservation: { command, _, debugCLI in
            handleStopObservationCommand(command: command, debugCLI: debugCLI)
        },
        .isProcessTrusted: { command, _, _ in handleIsProcessTrustedCommand(command: command) },
        .isAXFeatureEnabled: { command, _, _ in handleIsAXFeatureEnabledCommand(command: command) }
    ]

    private static let notImplementedCommands: Set<CommandType> = [
        .setNotificationHandler,
        .removeNotificationHandler,
        .getElementDescription
    ]

    @MainActor
    private static func processCommand(command: CommandEnvelope, axorcist: AXorcist, debugCLI: Bool) -> String {
        if let executor = simpleExecutors[command.command] {
            return handleSimpleCommand(
                command: command,
                axorcist: axorcist,
                debugCLI: debugCLI,
                executor: executor
            )
        }

        if let handler = commandHandlers[command.command] {
            return handler(command, axorcist, debugCLI)
        }

        if notImplementedCommands.contains(command.command) {
            return handleNotImplementedCommand(
                command: command,
                message: "\(command.command.rawValue) is not implemented in axorc",
                debugCLI: debugCLI
            )
        }

        axErrorLog("Unhandled command: \(command.command.rawValue)")
        return "{\"error\": \"Unhandled command \(command.command.rawValue)\", \"commandId\": \"\(command.commandId)\"}"
    }

    @MainActor
    private static func handleCollectAllCommand(
        command: CommandEnvelope,
        axorcist: AXorcist,
        debugCLI: Bool
    ) -> String {
        axDebugLog("CollectAll called. debugCLI=\(debugCLI). Passing to axorcist.handleCollectAll.")
        guard let axCommand = command.command.toAXCommand(commandEnvelope: command) else {
            axErrorLog("Failed to convert CollectAll to AXCommand")
            let errorResponse = HandlerResponse(
                data: nil,
                error: "Internal error: Failed to create AXCommand for CollectAll"
            )
            return finalizeAndEncodeResponse(
                commandId: command.commandId,
                commandType: command.command.rawValue,
                handlerResponse: errorResponse,
                debugCLI: debugCLI,
                commandDebugLogging: command.debugLogging
            )
        }
        let axResponse = axorcist.runCommand(AXCommandEnvelope(commandID: command.commandId, command: axCommand))
        let handlerResponse = if axResponse.status == "success" {
            HandlerResponse(data: axResponse.payload, error: nil)
        } else {
            HandlerResponse(data: nil, error: axResponse.error?.message ?? "CollectAll failed")
        }
        return finalizeAndEncodeResponse(
            commandId: command.commandId,
            commandType: command.command.rawValue,
            handlerResponse: handlerResponse,
            debugCLI: debugCLI,
            commandDebugLogging: command.debugLogging
        )
    }

    @MainActor
    private static func handleGetElementAtPointCommand(
        command: CommandEnvelope,
        axorcist: AXorcist,
        debugCLI: Bool
    ) -> String {
        handleSimpleCommand(command: command, axorcist: axorcist, debugCLI: debugCLI) { cmd, axorcist in
            guard let axCmd = cmd.command.toAXCommand(commandEnvelope: cmd) else {
                axErrorLog("Failed to convert GetElementAtPoint to AXCommand")
                return HandlerResponse(
                    data: nil,
                    error: "Internal error: Failed to create AXCommand for GetElementAtPoint"
                )
            }
            let axResponse = axorcist.runCommand(AXCommandEnvelope(commandID: cmd.commandId, command: axCmd))
            return HandlerResponse(from: axResponse)
        }
    }

    @MainActor
    private static func handleSetFocusedValueCommand(
        command: CommandEnvelope,
        axorcist: AXorcist,
        debugCLI: Bool
    ) -> String {
        handleSimpleCommand(command: command, axorcist: axorcist, debugCLI: debugCLI) { cmd, axorcist in
            guard let axCmd = cmd.command.toAXCommand(commandEnvelope: cmd) else {
                axErrorLog("Failed to convert SetFocusedValue to AXCommand")
                return HandlerResponse(
                    data: nil,
                    error: "Internal error: Failed to create AXCommand for SetFocusedValue"
                )
            }
            let axResponse = axorcist.runCommand(AXCommandEnvelope(commandID: cmd.commandId, command: axCmd))
            return HandlerResponse(from: axResponse)
        }
    }

    @MainActor
    private static func handleStopObservationCommand(command: CommandEnvelope, debugCLI: Bool) -> String {
        AXObserverCenter.shared.removeAllObservers()
        let stopResponse = FinalResponse(
            commandId: command.commandId,
            commandType: command.command.rawValue,
            status: "success",
            data: AnyCodable("All observations stopped"),
            error: nil,
            debugLogs: debugCLI || command.debugLogging ? axGetLogsAsStrings() : nil
        )
        return encodeToJson(stopResponse) ??
            "{\"error\": \"Encoding stopObservation response failed\", \"commandId\": \"\(command.commandId)\"}"
    }

    @MainActor
    private static func handleIsProcessTrustedCommand(command: CommandEnvelope) -> String {
        let trustedResponse = ProcessTrustedResponse(
            commandId: command.commandId,
            status: "success",
            trusted: AXIsProcessTrusted()
        )
        return encodeToJson(trustedResponse) ??
            "{\"error\": \"Encoding isProcessTrusted response failed\", \"commandId\": \"\(command.commandId)\"}"
    }

    @MainActor
    private static func handleIsAXFeatureEnabledCommand(command: CommandEnvelope) -> String {
        let axEnabled = AXIsProcessTrustedWithOptions(nil)
        let featureEnabledResponse = AXFeatureEnabledResponse(
            commandId: command.commandId,
            status: "success",
            enabled: axEnabled
        )
        return encodeToJson(featureEnabledResponse) ??
            "{\"error\": \"Encoding isAXFeatureEnabled response failed\", \"commandId\": \"\(command.commandId)\"}"
    }
}
