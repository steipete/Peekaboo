import ApplicationServices
import ArgumentParser
import AXorcistLib
import Foundation

struct DialogCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dialog",
        abstract: "Interact with system dialogs and alerts",
        discussion: """
        Handle system dialogs, alerts, sheets, and file dialogs.

        EXAMPLES:
          # Click a button in a dialog
          peekaboo dialog click --button "OK"
          peekaboo dialog click --button "Don't Save"

          # Type in a dialog text field
          peekaboo dialog input --text "password123" --field "Password"

          # Handle file dialogs
          peekaboo dialog file --path "/Users/me/Documents/file.txt"
          peekaboo dialog file --name "report.pdf" --select "Save"

          # Dismiss dialogs
          peekaboo dialog dismiss
          peekaboo dialog dismiss --force  # Press Escape
        """,
        subcommands: [
            ClickSubcommand.self,
            InputSubcommand.self,
            FileSubcommand.self,
            DismissSubcommand.self,
            ListSubcommand.self,
        ])

    // MARK: - Click Dialog Button

    struct ClickSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "click",
            abstract: "Click a button in a dialog")

        @Option(help: "Button text to click (e.g., 'OK', 'Cancel', 'Save')")
        var button: String

        @Option(help: "Specific window/sheet title to target")
        var window: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                // Find the dialog
                let dialog = try findDialog(withTitle: window)

                // Find the button
                let buttons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []
                guard let targetButton = buttons.first(where: { btn in
                    btn.title() == button ||
                        btn.title()?.contains(button) == true
                }) else {
                    throw DialogError.buttonNotFound(self.button)
                }

                // Click the button
                try targetButton.performAction(.press)

                // Output result
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dialog_click",
                            "button": targetButton.title() ?? self.button,
                            "window": dialog.title() ?? "Dialog",
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Clicked '\(targetButton.title() ?? self.button)' button")
                }

            } catch let error as DialogError {
                handleDialogError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
            }
        }
    }

    // MARK: - Input Text in Dialog

    struct InputSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "input",
            abstract: "Enter text in a dialog field")

        @Option(help: "Text to enter")
        var text: String

        @Option(help: "Field label or placeholder to target")
        var field: String?

        @Option(help: "Field index (0-based) if multiple fields")
        var index: Int?

        @Flag(help: "Clear existing text first")
        var clear = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                // Find the dialog
                let dialog = try findDialog(withTitle: nil)

                // Find text fields
                let textFields = findTextFields(in: dialog)
                guard !textFields.isEmpty else {
                    throw DialogError.noTextFields
                }

                // Select target field
                var targetField: Element?

                if let fieldLabel = field {
                    // Find by label
                    targetField = textFields.first { field in
                        field.title() == fieldLabel ||
                            field.attribute(Attribute<String>("AXPlaceholderValue")) == fieldLabel ||
                            field.descriptionText()?.contains(fieldLabel) == true
                    }

                    if targetField == nil {
                        throw DialogError.fieldNotFound(fieldLabel)
                    }
                } else if let fieldIndex = index {
                    // Find by index
                    guard fieldIndex < textFields.count else {
                        throw DialogError.invalidFieldIndex(fieldIndex)
                    }
                    targetField = textFields[fieldIndex]
                } else {
                    // Use first field
                    targetField = textFields.first
                }

                guard let field = targetField else {
                    throw DialogError.noTextFields
                }

                // Focus the field
                try field.performAction(.press)

                // Clear if requested
                if self.clear {
                    // Select all and delete
                    let selectAll = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) // A
                    selectAll?.flags = .maskCommand
                    selectAll?.post(tap: .cghidEventTap)

                    let deleteKey = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) // Delete
                    deleteKey?.post(tap: .cghidEventTap)
                }

                // Type the text
                for char in self.text {
                    typeCharacter(char)
                    usleep(10000) // 10ms between characters
                }

                // Output result
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "dialog_input",
                            "field": field.title() ?? "Text Field",
                            "text_length": self.text.count,
                            "cleared": self.clear,
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Entered text in '\(field.title() ?? "field")'")
                }

            } catch let error as DialogError {
                handleDialogError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
            }
        }
    }

    // MARK: - Handle File Dialog

    struct FileSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "file",
            abstract: "Handle file save/open dialogs")

        @Option(help: "Full file path to navigate to")
        var path: String?

        @Option(help: "File name to enter (for save dialogs)")
        var name: String?

        @Option(help: "Button to click after entering path/name")
        var select: String = "Save"

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                // Find the file dialog
                let dialog = try findFileDialog()

                // Handle file path navigation
                if let filePath = path {
                    // Use Go To folder shortcut (Cmd+Shift+G)
                    let cmdShiftG = CGEvent(keyboardEventSource: nil, virtualKey: 0x05, keyDown: true) // G
                    cmdShiftG?.flags = [.maskCommand, .maskShift]
                    cmdShiftG?.post(tap: .cghidEventTap)

                    // Wait for go to sheet
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms

                    // Type the path
                    for char in filePath {
                        typeCharacter(char)
                        usleep(5000) // 5ms between characters
                    }

                    // Press Enter
                    let enter = CGEvent(keyboardEventSource: nil, virtualKey: 0x24, keyDown: true) // Return
                    enter?.post(tap: .cghidEventTap)

                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }

                // Handle file name
                if let fileName = name {
                    // Find the name field
                    let textFields = findTextFields(in: dialog)
                    if let nameField = textFields.first {
                        // Clear and type new name
                        try nameField.performAction(.press)

                        // Select all
                        let selectAll = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) // A
                        selectAll?.flags = .maskCommand
                        selectAll?.post(tap: .cghidEventTap)

                        // Type the name
                        for char in fileName {
                            typeCharacter(char)
                            usleep(5000) // 5ms between characters
                        }
                    }
                }

                // Click the action button
                let buttons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []
                if let actionButton = buttons.first(where: { $0.title() == select }) {
                    try actionButton.performAction(.press)
                }

                // Output result
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "file_dialog",
                            "path": path,
                            "name": name,
                            "button_clicked": select,
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Handled file dialog")
                    if let p = path { print("  Path: \(p)") }
                    if let n = name { print("  Name: \(n)") }
                    print("  Action: \(self.select)")
                }

            } catch let error as DialogError {
                handleDialogError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
            }
        }
    }

    // MARK: - Dismiss Dialog

    struct DismissSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "dismiss",
            abstract: "Dismiss a dialog")

        @Flag(help: "Force dismiss with Escape key")
        var force = false

        @Option(help: "Specific window/sheet title to target")
        var window: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                if self.force {
                    // Press Escape
                    let escape = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: true) // Escape
                    escape?.post(tap: .cghidEventTap)

                    // Output result
                    if self.jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "dialog_dismiss",
                                "method": "escape",
                            ]))
                        outputJSON(response)
                    } else {
                        print("✓ Dismissed dialog with Escape")
                    }
                } else {
                    // Find and click Cancel or Close button
                    let dialog = try findDialog(withTitle: window)
                    let buttons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []

                    // Look for common dismiss buttons
                    let dismissButtons = ["Cancel", "Close", "Dismiss", "No", "Don't Save"]
                    var clicked = false

                    for buttonName in dismissButtons {
                        if let button = buttons.first(where: { $0.title() == buttonName }) {
                            try button.performAction(.press)
                            clicked = true

                            // Output result
                            if self.jsonOutput {
                                let response = JSONResponse(
                                    success: true,
                                    data: AnyCodable([
                                        "action": "dialog_dismiss",
                                        "method": "button",
                                        "button": buttonName,
                                    ]))
                                outputJSON(response)
                            } else {
                                print("✓ Dismissed dialog by clicking '\(buttonName)'")
                            }
                            break
                        }
                    }

                    if !clicked {
                        throw DialogError.noDismissButton
                    }
                }

            } catch let error as DialogError {
                handleDialogError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
            }
        }
    }

    // MARK: - List Dialog Elements

    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List elements in current dialog")

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        func run() async throws {
            do {
                // Find any open dialog
                let dialog = try findDialog(withTitle: nil)

                // Collect dialog information
                var dialogInfo: [String: Any] = [
                    "title": dialog.title() ?? "Untitled Dialog",
                    "role": dialog.role() ?? "Unknown",
                ]

                // Get buttons
                let buttons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []
                dialogInfo["buttons"] = buttons.compactMap { $0.title() }

                // Get text fields
                let textFields = findTextFields(in: dialog)
                dialogInfo["text_fields"] = textFields.map { field in
                    [
                        "title": field.title() ?? "",
                        "value": field.value() as? String ?? "",
                        "placeholder": field.attribute(Attribute<String>("AXPlaceholderValue")) ?? "",
                    ]
                }

                // Get static text
                let staticTexts = dialog.children()?.filter { $0.role() == "AXStaticText" } ?? []
                dialogInfo["text_elements"] = staticTexts.compactMap { $0.value() as? String }

                // Output result
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable(dialogInfo))
                    outputJSON(response)
                } else {
                    print("Dialog: \(dialogInfo["title"] ?? "Untitled")")

                    if let buttons = dialogInfo["buttons"] as? [String], !buttons.isEmpty {
                        print("\nButtons:")
                        buttons.forEach { print("  • \($0)") }
                    }

                    if let fields = dialogInfo["text_fields"] as? [[String: String]], !fields.isEmpty {
                        print("\nText Fields:")
                        for field in fields {
                            let title = field["title"] ?? "Untitled"
                            let placeholder = field["placeholder"] ?? ""
                            print("  • \(title) [\(placeholder)]")
                        }
                    }

                    if let texts = dialogInfo["text_elements"] as? [String], !texts.isEmpty {
                        print("\nText:")
                        texts.forEach { print("  \($0)") }
                    }
                }

            } catch let error as DialogError {
                handleDialogError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
            }
        }
    }
}

// MARK: - Helper Functions

@MainActor
private func findDialog(withTitle title: String?) throws -> Element {
    // Get frontmost application
    let systemWide = Element.systemWide()
    guard let focusedApp = systemWide.focusedApplication() else {
        throw DialogError.noActiveDialog
    }

    // Look for windows that are likely dialogs
    let windows = focusedApp.windows() ?? []

    for window in windows {
        let role = window.role() ?? ""
        let subrole = window.subrole() ?? ""

        // Check if it's a dialog-like window
        if role == "AXWindow", subrole == "AXDialog" || subrole == "AXSystemDialog" {
            if let targetTitle = title {
                if window.title() == targetTitle {
                    return window
                }
            } else {
                return window
            }
        }

        // Check for sheets
        if let sheet = window.children()?.first(where: { $0.role() == "AXSheet" }) {
            if let targetTitle = title {
                if sheet.title() == targetTitle {
                    return sheet
                }
            } else {
                return sheet
            }
        }
    }

    // Also check for floating panels
    for window in windows {
        if window.subrole() == "AXFloatingWindow" || window.subrole() == "AXSystemFloatingWindow" {
            if let targetTitle = title {
                if window.title() == targetTitle {
                    return window
                }
            } else {
                return window
            }
        }
    }

    throw DialogError.noActiveDialog
}

@MainActor
private func findFileDialog() throws -> Element {
    // File dialogs often have specific subroles
    let systemWide = Element.systemWide()
    guard let focusedApp = systemWide.focusedApplication() else {
        throw DialogError.noActiveDialog
    }

    let windows = focusedApp.windows() ?? []

    for window in windows {
        // Check for save/open panels
        if window.role() == "AXWindow" {
            let title = window.title() ?? ""
            if title.contains("Save") || title.contains("Open") || title.contains("Export") {
                return window
            }
        }
    }

    throw DialogError.noFileDialog
}

@MainActor
private func findTextFields(in element: Element) -> [Element] {
    var fields: [Element] = []

    func collectFields(from el: Element) {
        if el.role() == "AXTextField" || el.role() == "AXTextArea" {
            fields.append(el)
        }

        if let children = el.children() {
            for child in children {
                collectFields(from: child)
            }
        }
    }

    collectFields(from: element)
    return fields
}

private func typeCharacter(_ char: Character) {
    // Convert character to key code
    // This is a simplified version - a full implementation would handle all characters
    let keyMap: [Character: (CGKeyCode, Bool)] = [
        "a": (0x00, false), "A": (0x00, true),
        "b": (0x0B, false), "B": (0x0B, true),
        "c": (0x08, false), "C": (0x08, true),
        // ... add more mappings as needed
        " ": (0x31, false),
        ".": (0x2F, false),
        "/": (0x2C, false),
        "-": (0x1B, false),
        "_": (0x1B, true),
    ]

    if let (keyCode, needsShift) = keyMap[char] {
        if needsShift {
            let shiftDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: true)
            shiftDown?.post(tap: .cghidEventTap)
        }

        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        if needsShift {
            let shiftUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: false)
            shiftUp?.post(tap: .cghidEventTap)
        }
    } else {
        // Fallback: type as unicode
        let str = String(char)
        let utf16 = Array(str.utf16)
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        utf16.withUnsafeBufferPointer { buffer in
            keyDown?.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress!)
        }
        keyDown?.post(tap: .cghidEventTap)
    }
}

// MARK: - Dialog Errors

enum DialogError: LocalizedError {
    case noActiveDialog
    case noFileDialog
    case buttonNotFound(String)
    case fieldNotFound(String)
    case invalidFieldIndex(Int)
    case noTextFields
    case noDismissButton

    var errorDescription: String? {
        switch self {
        case .noActiveDialog:
            "No active dialog found"
        case .noFileDialog:
            "No file dialog found"
        case let .buttonNotFound(button):
            "Button '\(button)' not found in dialog"
        case let .fieldNotFound(field):
            "Field '\(field)' not found in dialog"
        case let .invalidFieldIndex(index):
            "Invalid field index: \(index)"
        case .noTextFields:
            "No text fields found in dialog"
        case .noDismissButton:
            "No dismiss button found in dialog"
        }
    }

    var errorCode: String {
        switch self {
        case .noActiveDialog:
            "NO_ACTIVE_DIALOG"
        case .noFileDialog:
            "NO_FILE_DIALOG"
        case .buttonNotFound:
            "BUTTON_NOT_FOUND"
        case .fieldNotFound:
            "FIELD_NOT_FOUND"
        case .invalidFieldIndex:
            "INVALID_FIELD_INDEX"
        case .noTextFields:
            "NO_TEXT_FIELDS"
        case .noDismissButton:
            "NO_DISMISS_BUTTON"
        }
    }
}

// MARK: - Error Handling

private func handleDialogError(_ error: DialogError, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: ErrorCode(rawValue: error.errorCode) ?? .UNKNOWN_ERROR))
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}
