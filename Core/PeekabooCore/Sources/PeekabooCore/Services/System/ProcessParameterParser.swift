import Foundation

/// Helper to parse ProcessCommandParameters for specific commands
@available(macOS 14.0, *)
struct ProcessParameterParser {
    
    /// Parse generic parameters into strongly-typed command parameters
    static func parseParameters(for command: String, from params: ProcessCommandParameters?) -> ProcessCommandParameters? {
        // If already typed correctly, return as-is
        guard let params = params else { return nil }
        
        // Handle generic parameters by converting them to typed ones
        if case .generic(let dict) = params {
            switch command.lowercased() {
            case "click":
                return parseClickParameters(from: dict)
            case "type":
                return parseTypeParameters(from: dict)
            case "hotkey":
                return parseHotkeyParameters(from: dict)
            case "scroll":
                return parseScrollParameters(from: dict)
            case "menu":
                return parseMenuParameters(from: dict)
            case "dialog":
                return parseDialogParameters(from: dict)
            case "launch", "app":
                return parseLaunchAppParameters(from: dict)
            case "find":
                return parseFindElementParameters(from: dict)
            case "screenshot", "see":
                return parseScreenshotParameters(from: dict)
            case "focus":
                return parseFocusWindowParameters(from: dict)
            case "resize":
                return parseResizeWindowParameters(from: dict)
            default:
                return params // Return generic for unknown commands
            }
        }
        
        return params
    }
    
    // MARK: - Command-specific parsers
    
    private static func parseClickParameters(from dict: [String: String]) -> ProcessCommandParameters {
        return .click(ProcessCommandParameters.ClickParameters(
            x: dict["x"].flatMap { Double($0) },
            y: dict["y"].flatMap { Double($0) },
            label: dict["label"],
            app: dict["app"],
            button: dict["button"],
            modifiers: parseModifiers(from: dict)
        ))
    }
    
    private static func parseTypeParameters(from dict: [String: String]) -> ProcessCommandParameters {
        guard let text = dict["text"] else {
            return .generic(dict)
        }
        
        return .type(ProcessCommandParameters.TypeParameters(
            text: text,
            app: dict["app"],
            field: dict["field"],
            clearFirst: dict["clearFirst"].flatMap { Bool($0) } ?? dict["clear_first"].flatMap { Bool($0) }
        ))
    }
    
    private static func parseHotkeyParameters(from dict: [String: String]) -> ProcessCommandParameters {
        guard let key = dict["key"] else {
            return .generic(dict)
        }
        
        return .hotkey(ProcessCommandParameters.HotkeyParameters(
            key: key,
            modifiers: parseModifiers(from: dict),
            app: dict["app"]
        ))
    }
    
    private static func parseScrollParameters(from dict: [String: String]) -> ProcessCommandParameters {
        let direction = dict["direction"] ?? "down"
        
        return .scroll(ProcessCommandParameters.ScrollParameters(
            direction: direction,
            amount: dict["amount"].flatMap { Int($0) },
            app: dict["app"],
            target: dict["target"]
        ))
    }
    
    private static func parseMenuParameters(from dict: [String: String]) -> ProcessCommandParameters {
        // Parse menu path from various formats
        var menuPath: [String] = []
        
        if let path = dict["path"] {
            menuPath = path.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        } else if let menu = dict["menu"], let item = dict["item"] {
            menuPath = [menu, item]
            if let submenu = dict["submenu"] {
                menuPath.insert(submenu, at: 1)
            }
        }
        
        return .menuClick(ProcessCommandParameters.MenuClickParameters(
            menuPath: menuPath,
            app: dict["app"]
        ))
    }
    
    private static func parseDialogParameters(from dict: [String: String]) -> ProcessCommandParameters {
        let action = dict["action"] ?? "click"
        
        return .dialog(ProcessCommandParameters.DialogParameters(
            action: action,
            buttonLabel: dict["button"] ?? dict["buttonLabel"],
            inputText: dict["text"] ?? dict["inputText"],
            fieldLabel: dict["field"] ?? dict["fieldLabel"]
        ))
    }
    
    private static func parseLaunchAppParameters(from dict: [String: String]) -> ProcessCommandParameters {
        guard let appName = dict["app"] ?? dict["name"] ?? dict["appName"] else {
            return .generic(dict)
        }
        
        return .launchApp(ProcessCommandParameters.LaunchAppParameters(
            appName: appName,
            waitForLaunch: dict["wait"].flatMap { Bool($0) } ?? dict["waitForLaunch"].flatMap { Bool($0) },
            bringToFront: dict["focus"].flatMap { Bool($0) } ?? dict["bringToFront"].flatMap { Bool($0) }
        ))
    }
    
    private static func parseFindElementParameters(from dict: [String: String]) -> ProcessCommandParameters {
        return .findElement(ProcessCommandParameters.FindElementParameters(
            label: dict["label"],
            identifier: dict["identifier"] ?? dict["id"],
            type: dict["type"] ?? dict["elementType"],
            app: dict["app"]
        ))
    }
    
    private static func parseScreenshotParameters(from dict: [String: String]) -> ProcessCommandParameters {
        let path = dict["path"] ?? dict["outputPath"] ?? "screenshot.png"
        
        return .screenshot(ProcessCommandParameters.ScreenshotParameters(
            path: path,
            app: dict["app"],
            window: dict["window"],
            display: dict["display"].flatMap { Int($0) }
        ))
    }
    
    private static func parseFocusWindowParameters(from dict: [String: String]) -> ProcessCommandParameters {
        return .focusWindow(ProcessCommandParameters.FocusWindowParameters(
            app: dict["app"],
            title: dict["title"] ?? dict["window"],
            index: dict["index"].flatMap { Int($0) }
        ))
    }
    
    private static func parseResizeWindowParameters(from dict: [String: String]) -> ProcessCommandParameters {
        return .resizeWindow(ProcessCommandParameters.ResizeWindowParameters(
            width: dict["width"].flatMap { Int($0) },
            height: dict["height"].flatMap { Int($0) },
            x: dict["x"].flatMap { Int($0) },
            y: dict["y"].flatMap { Int($0) },
            app: dict["app"],
            maximize: dict["maximize"].flatMap { Bool($0) },
            minimize: dict["minimize"].flatMap { Bool($0) }
        ))
    }
    
    // MARK: - Helper methods
    
    private static func parseModifiers(from dict: [String: String]) -> [String] {
        var modifiers: [String] = []
        
        // Check individual modifier flags
        if dict["cmd"] == "true" || dict["command"] == "true" {
            modifiers.append("command")
        }
        if dict["shift"] == "true" {
            modifiers.append("shift")
        }
        if dict["option"] == "true" || dict["alt"] == "true" {
            modifiers.append("option")
        }
        if dict["control"] == "true" || dict["ctrl"] == "true" {
            modifiers.append("control")
        }
        if dict["fn"] == "true" || dict["function"] == "true" {
            modifiers.append("function")
        }
        
        // Also check modifiers array
        if let modifiersStr = dict["modifiers"] {
            let additionalMods = modifiersStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            modifiers.append(contentsOf: additionalMods)
        }
        
        return modifiers
    }
}