import Commander
import Foundation
import PeekabooAutomationKit
import PeekabooFoundation
import UniformTypeIdentifiers

extension CommanderCLIBinder {
    static func applyRoutePermissionOptions(
        _ options: inout CommandRuntimeOptions,
        _ commandType: (any ParsableCommand.Type)?,
        values: CommanderBindableValues
    ) {
        let foreground = values.flag("foreground")
        let hasWindow = ["windowId", "windowTitle", "windowIndex"].contains {
            values.singleOption($0) != nil
        }
        let hasSnapshot = values.singleOption("snapshot")?.isEmpty == false
        let hasProcess = values.singleOption("app") != nil || values.singleOption("pid") != nil
        let needsForegroundFocus = foreground && (hasWindow || hasSnapshot || hasProcess) &&
            !values.flag("noAutoFocus")
        let strategy = options.inputStrategy

        if commandType == TypeCommand.self || commandType == PasteCommand.self {
            let pixelFocus = commandType == TypeCommand.self && values.singleOption("at") != nil
            let exactReceiver = !foreground && (hasWindow || (commandType == TypeCommand.self && hasSnapshot))
            options.requiresTargetedFocusedElement = exactReceiver && !pixelFocus
            let route: PastePermissionRoute = if commandType == TypeCommand.self {
                .text
            } else {
                foreground ? .hotkey : self.pastePermissionRoute(values)
            }
            let textStrategy = strategy ?? UIInputPolicy.currentBehavior.backgroundTypingStrategy()
            let hotkeyStrategy = strategy ?? UIInputPolicy.currentBehavior.strategy(for: .hotkey)
            // App/PID-only input may resolve to a process with no window. AX-first text
            // delivery still needs AX; explicit exact receivers always need AX focus checks.
            options.routeRequiresAccessibilityPermission = pixelFocus || exactReceiver || needsForegroundFocus ||
                (!foreground && route == .text && textStrategy.attemptsAccessibilityFirst) ||
                strategy == .actionOnly
            options.routeRequiresPostEventPermission = switch route {
            case .text:
                foreground || textStrategy.usesSynthesisDirectly
            case .hotkey:
                hotkeyStrategy.usesSynthesisDirectly || (exactReceiver && hotkeyStrategy != .actionOnly)
            case .payloadDependent:
                // Both possible routes synthesize only when explicitly selected.
                strategy?.usesSynthesisDirectly == true
            }
        } else if commandType == PressCommand.self {
            options.requiresTargetedFocusedElement = !foreground
            options
                .routeRequiresAccessibilityPermission = !foreground || strategy == .actionOnly || needsForegroundFocus
            let chords = values.positional.isEmpty ? values.singleOption("key").map { [$0] } ?? [] : values.positional
            // Exact-window Cmd+A can use AX selection. Other raw chords cannot use
            // app-wide menu actions to certify the exact receiver.
            let needsRawChord = chords.contains { (try? KeyboardChord(parsing: $0).keys) != ["cmd", "a"] }
            let hotkeyStrategy = strategy ?? UIInputPolicy.currentBehavior.strategy(for: .hotkey)
            options.routeRequiresPostEventPermission = foreground
                ? hotkeyStrategy.usesSynthesisDirectly
                : strategy != .actionOnly && (strategy?.usesSynthesisDirectly == true || needsRawChord)
        } else if self.isAXWindowCommand(commandType) ||
            commandType == MenuCommand.ClickSubcommand.self || commandType == MenuCommand.ListSubcommand.self {
            options.routeRequiresAccessibilityPermission = true
        } else if commandType == MenuBarCommand.ClickSubcommand.self {
            // Scoped items use AX actions; global names/indices resolve WindowServer geometry.
            options.routeRequiresAccessibilityPermission = hasProcess
            options.routeRequiresPostEventPermission = !hasProcess
        }
        // App hide/focus retain native NSRunningApplication routes. Window/menubar
        // inventory and clipboard writes also have grant-free native routes.
    }

    private enum PastePermissionRoute {
        case text, hotkey, payloadDependent
    }

    private static func pastePermissionRoute(_ values: CommanderBindableValues) -> PastePermissionRoute {
        if values.positional.first != nil || values.singleOption("text") != nil ||
            values.singleOption("textOption") != nil {
            return .text
        }
        if values.singleOption("filePath") != nil {
            if let uti = values.singleOption("uti").flatMap(UTType.init),
               uti != .plainText, uti != .utf8PlainText {
                return .hotkey
            }
            // File bytes can still fail UTF-8 decoding even with a plain-text UTI.
            return .payloadDependent
        }
        if let base64 = values.singleOption("dataBase64"), let uti = values.singleOption("uti"),
           uti == UTType.plainText.identifier || uti == UTType.utf8PlainText.identifier,
           let data = Data(base64Encoded: base64), String(data: data, encoding: .utf8) != nil {
            return .text
        }
        return .hotkey
    }

    private static func isAXWindowCommand(_ commandType: (any ParsableCommand.Type)?) -> Bool {
        commandType == WindowCommand.CloseSubcommand.self ||
            commandType == WindowCommand.MinimizeSubcommand.self ||
            commandType == WindowCommand.RestoreSubcommand.self ||
            commandType == WindowCommand.MaximizeSubcommand.self ||
            commandType == WindowCommand.MoveSubcommand.self ||
            commandType == WindowCommand.ResizeSubcommand.self ||
            commandType == WindowCommand.SetBoundsSubcommand.self ||
            commandType == WindowCommand.FocusSubcommand.self
    }
}

extension UIInputStrategy {
    fileprivate var attemptsAccessibilityFirst: Bool {
        self == .actionFirst || self == .actionOnly
    }

    fileprivate var usesSynthesisDirectly: Bool {
        self == .synthFirst || self == .synthOnly
    }
}
