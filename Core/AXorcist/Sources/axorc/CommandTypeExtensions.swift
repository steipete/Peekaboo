// CommandTypeExtensions.swift - Extensions for CommandType conversions

import AXorcist
import Foundation

// MARK: - CommandType Extension for conversion to AXCommand

extension CommandType {
    func toAXCommand(commandEnvelope: CommandEnvelope) -> AXCommand? {
        guard let builder = Self.commandBuilders[self] else { return nil }
        return builder(commandEnvelope)
    }

    private typealias CommandBuilder = (CommandEnvelope) -> AXCommand?

    private static let commandBuilders: [CommandType: CommandBuilder] = [
        .query: Self.createQueryCommand,
        .performAction: Self.createPerformActionCommand,
        .getAttributes: Self.createGetAttributesCommand,
        .describeElement: Self.createDescribeElementCommand,
        .extractText: Self.createExtractTextCommand,
        .collectAll: Self.createCollectAllCommand,
        .batch: Self.createBatchCommand,
        .setFocusedValue: Self.createSetFocusedValueCommand,
        .getElementAtPoint: Self.createGetElementAtPointCommand,
        .getFocusedElement: Self.createGetFocusedElementCommand,
        .observe: Self.createObserveCommand,
    ]

    private static func createQueryCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand {
        let effectiveLocator = commandEnvelope.locator ?? Locator(criteria: [])
        return .query(QueryCommand(
            appIdentifier: commandEnvelope.application,
            locator: Locator(
                matchAll: effectiveLocator.matchAll,
                criteria: effectiveLocator.criteria,
                rootElementPathHint: effectiveLocator.rootElementPathHint,
                descendantCriteria: effectiveLocator.descendantCriteria,
                requireAction: effectiveLocator.requireAction,
                computedNameContains: effectiveLocator.computedNameContains,
                debugPathSearch: commandEnvelope.locator?.debugPathSearch
            ),
            attributesToReturn: commandEnvelope.attributes,
            maxDepthForSearch: commandEnvelope.maxDepth ?? 10,
            includeChildrenBrief: commandEnvelope.includeChildrenBrief
        ))
    }

    private static func createPerformActionCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand? {
        guard let actionName = commandEnvelope.actionName else { return nil }
        return .performAction(PerformActionCommand(
            appIdentifier: commandEnvelope.application,
            locator: commandEnvelope.locator ?? Locator(criteria: []),
            action: actionName,
            value: commandEnvelope.actionValue,
            maxDepthForSearch: commandEnvelope.maxDepth ?? 10
        ))
    }

    private static func createGetAttributesCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand {
        .getAttributes(GetAttributesCommand(
            appIdentifier: commandEnvelope.application,
            locator: commandEnvelope.locator ?? Locator(criteria: []),
            attributes: commandEnvelope.attributes ?? [],
            maxDepthForSearch: commandEnvelope.maxDepth ?? 10
        ))
    }

    private static func createDescribeElementCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand {
        .describeElement(DescribeElementCommand(
            appIdentifier: commandEnvelope.application,
            locator: commandEnvelope.locator ?? Locator(criteria: []),
            depth: commandEnvelope.maxDepth ?? 3,
            includeIgnored: commandEnvelope.includeIgnoredElements ?? false,
            maxSearchDepth: commandEnvelope.maxDepth ?? 10
        ))
    }

    private static func createExtractTextCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand {
        .extractText(ExtractTextCommand(
            appIdentifier: commandEnvelope.application,
            locator: commandEnvelope.locator ?? Locator(criteria: []),
            maxDepthForSearch: commandEnvelope.maxDepth ?? 10,
            includeChildren: commandEnvelope.includeChildrenInText ?? false,
            maxDepth: commandEnvelope.maxDepth
        ))
    }

    private static func createCollectAllCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand {
        .collectAll(CollectAllCommand(
            appIdentifier: commandEnvelope.application,
            attributesToReturn: commandEnvelope.attributes,
            maxDepth: commandEnvelope.maxDepth ?? 10,
            filterCriteria: commandEnvelope.filterCriteria,
            valueFormatOption: ValueFormatOption.smart
        ))
    }

    private static func createBatchCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand? {
        guard let batchSubCommands = commandEnvelope.subCommands else {
            axErrorLog("toAXCommand: Batch command missing subCommands in CommandEnvelope.")
            return nil
        }
        let axSubCommands = batchSubCommands.compactMap { subCmdEnv -> AXBatchCommand.SubCommandEnvelope? in
            guard let axSubCmd = subCmdEnv.command.toAXCommand(commandEnvelope: subCmdEnv) else {
                let message = "Failed to convert subCommand '\(subCmdEnv.commandId)' of type " +
                    "'\(subCmdEnv.command.rawValue)' to AXCommand."
                axErrorLog("toAXCommand: \(message)")
                return nil
            }
            return AXBatchCommand.SubCommandEnvelope(commandID: subCmdEnv.commandId, command: axSubCmd)
        }
        if axSubCommands.count != batchSubCommands.count {
            axErrorLog(
                "toAXCommand: Some subCommands in batch failed. Original: \(batchSubCommands.count), " +
                    "Converted: \(axSubCommands.count)"
            )
        }
        return .batch(AXBatchCommand(commands: axSubCommands))
    }

    private static func createSetFocusedValueCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand? {
        guard let value = commandEnvelope.actionValue?.value as? String else {
            axErrorLog("toAXCommand: SetFocusedValue missing string value in actionValue or wrong type.")
            return nil
        }
        return .setFocusedValue(SetFocusedValueCommand(
            appIdentifier: commandEnvelope.application,
            locator: commandEnvelope.locator ?? Locator(criteria: []),
            value: value,
            maxDepthForSearch: commandEnvelope.maxDepth ?? 10
        ))
    }

    private static func createGetElementAtPointCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand? {
        guard let point = commandEnvelope.point else {
            axErrorLog("toAXCommand: GetElementAtPoint missing point.")
            return nil
        }
        return .getElementAtPoint(GetElementAtPointCommand(
            point: point,
            appIdentifier: commandEnvelope.application,
            pid: commandEnvelope.pid,
            attributesToReturn: commandEnvelope.attributes,
            includeChildrenBrief: commandEnvelope.includeChildrenBrief
        ))
    }

    private static func createGetFocusedElementCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand {
        .getFocusedElement(GetFocusedElementCommand(
            appIdentifier: commandEnvelope.application,
            attributesToReturn: commandEnvelope.attributes,
            includeChildrenBrief: commandEnvelope.includeChildrenBrief
        ))
    }

    private static func createObserveCommand(_ commandEnvelope: CommandEnvelope) -> AXCommand? {
        guard let notificationsList = commandEnvelope.notifications, !notificationsList.isEmpty else {
            axErrorLog("toAXCommand: Observe missing notifications list.")
            return nil
        }
        guard
            let firstNotificationName = notificationsList.first,
            let axNotification = AXNotification(rawValue: firstNotificationName)
        else {
            let invalidName = notificationsList.first ?? "nil"
            axErrorLog("toAXCommand: invalid notification name \(invalidName) for observe command.")
            return nil
        }
        return .observe(ObserveCommand(
            appIdentifier: commandEnvelope.application,
            locator: commandEnvelope.locator,
            notifications: notificationsList,
            includeDetails: true,
            watchChildren: commandEnvelope.watchChildren ?? false,
            notificationName: axNotification,
            includeElementDetails: commandEnvelope.includeElementDetails,
            maxDepthForSearch: commandEnvelope.maxDepth ?? 10
        ))
    }
}
