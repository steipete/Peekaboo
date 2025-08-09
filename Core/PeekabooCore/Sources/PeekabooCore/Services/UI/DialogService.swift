import AppKit
import PeekabooFoundation
import ApplicationServices
import AXorcist
import Foundation
import os.log

/// Dialog-specific errors
public enum DialogError: Error {
    case noActiveDialog
    case dialogNotFound
    case noFileDialog
    case buttonNotFound(String)
    case fieldNotFound
    case invalidFieldIndex
    case noTextFields
    case noDismissButton
}

/// Default implementation of dialog management operations
@MainActor
public final class DialogService: DialogServiceProtocol {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "DialogService")

    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared

    public init() {
        self.logger.debug("DialogService initialized")
        // Connect to visualizer if available
        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }

    public func findActiveDialog(windowTitle: String?) async throws -> DialogInfo {
        self.logger.info("Finding active dialog")
        if let title = windowTitle {
            self.logger.debug("Looking for window with title: \(title)")
        }

        let element = try findDialogElement(withTitle: windowTitle)

        let title = element.title() ?? "Untitled Dialog"
        let role = element.role() ?? "Unknown"
        let subrole = element.subrole()

        // Check if it's a file dialog
        let isFileDialog = title.contains("Save") || title.contains("Open") ||
            title.contains("Export") || title.contains("Import")

        let position = element.position() ?? .zero
        let size = element.size() ?? .zero
        let bounds = CGRect(origin: position, size: size)

        let info = DialogInfo(
            title: title,
            role: role,
            subrole: subrole,
            isFileDialog: isFileDialog,
            bounds: bounds)

        self.logger.info("✅ Found dialog: \(title), file dialog: \(isFileDialog)")
        return info
    }

    public func clickButton(buttonText: String, windowTitle: String?) async throws -> DialogActionResult {
        self.logger.info("Clicking button: \(buttonText)")
        if let title = windowTitle {
            self.logger.debug("In window: \(title)")
        }

        let dialog = try findDialogElement(withTitle: windowTitle)

        // Find buttons
        let buttons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []
        self.logger.debug("Found \(buttons.count) buttons in dialog")

        // Find target button (exact match or contains)
        guard let targetButton = buttons.first(where: { btn in
            btn.title() == buttonText || btn.title()?.contains(buttonText) == true
        }) else {
            throw PeekabooError.elementNotFound("\(buttonText)")
        }

        // Get button bounds for visual feedback
        let buttonBounds: CGRect = if let position = targetButton.position(), let size = targetButton.size() {
            CGRect(origin: position, size: size)
        } else {
            .zero
        }

        // Show dialog interaction visual feedback
        if buttonBounds != .zero {
            _ = await self.visualizerClient.showDialogInteraction(
                element: "button",
                elementRect: buttonBounds,
                action: "click")
        }

        // Click the button
        self.logger.debug("Clicking button: \(targetButton.title() ?? buttonText)")
        try targetButton.performAction(.press)

        let result = DialogActionResult(
            success: true,
            action: .clickButton,
            details: [
                "button": targetButton.title() ?? buttonText,
                "window": dialog.title() ?? "Dialog",
            ])

        self.logger.info("✅ Successfully clicked button: \(targetButton.title() ?? buttonText)")
        return result
    }

    public func enterText(
        text: String,
        fieldIdentifier: String?,
        clearExisting: Bool,
        windowTitle: String?) async throws -> DialogActionResult
    {
        self.logger.info("Entering text into dialog field")
        self.logger.debug("Text length: \(text.count) chars, clear existing: \(clearExisting)")
        if let identifier = fieldIdentifier {
            self.logger.debug("Target field: \(identifier)")
        }

        let dialog = try findDialogElement(withTitle: windowTitle)

        // Find text fields
        let textFields = self.collectTextFields(from: dialog)
        self.logger.debug("Found \(textFields.count) text fields")

        guard !textFields.isEmpty else {
            self.logger.error("No text fields found in dialog")
            throw PeekabooError.operationError(message: "No text fields found in dialog.")
        }

        // Select target field
        let targetField: Element

        if let identifier = fieldIdentifier {
            // Try to parse as index
            if let index = Int(identifier) {
                guard index < textFields.count else {
                    throw PeekabooError
                        .invalidInput("Invalid field index: \(index). Dialog has \(textFields.count) fields.")
                }
                targetField = textFields[index]
            } else {
                // Find by label/placeholder
                guard let field = textFields.first(where: { field in
                    field.title() == identifier ||
                        field.attribute(Attribute<String>("AXPlaceholderValue")) == identifier ||
                        field.descriptionText()?.contains(identifier) == true
                }) else {
                    throw PeekabooError.elementNotFound("\(identifier)")
                }
                targetField = field
            }
        } else {
            // Use first field
            targetField = textFields[0]
        }

        // Get field bounds for visual feedback
        let fieldBounds: CGRect = if let position = targetField.position(), let size = targetField.size() {
            CGRect(origin: position, size: size)
        } else {
            .zero
        }

        // Show dialog interaction visual feedback for text field
        if fieldBounds != .zero {
            _ = await self.visualizerClient.showDialogInteraction(
                element: "textField",
                elementRect: fieldBounds,
                action: "typeText")
        }

        // Focus the field
        self.logger.debug("Focusing text field")
        try targetField.performAction(.press)

        // Clear if requested
        if clearExisting {
            self.logger.debug("Clearing existing text")

            // Select all (Cmd+A)
            let selectAll = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) // A
            selectAll?.flags = .maskCommand
            selectAll?.post(tap: .cghidEventTap)

            // Delete
            let deleteKey = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) // Delete
            deleteKey?.post(tap: .cghidEventTap)

            // Small delay
            usleep(50000) // 50ms
        }

        // Type the text
        self.logger.debug("Typing text into field")
        for char in text {
            try self.typeCharacter(char)
            usleep(10000) // 10ms between characters
        }

        let result = DialogActionResult(
            success: true,
            action: .enterText,
            details: [
                "field": targetField.title() ?? "Text Field",
                "text_length": String(text.count),
                "cleared": String(clearExisting),
            ])

        self.logger.info("✅ Successfully entered text into field")
        return result
    }

    public func handleFileDialog(
        path: String?,
        filename: String?,
        actionButton: String = "Save") async throws -> DialogActionResult
    {
        self.logger.info("Handling file dialog")
        if let path {
            self.logger.debug("Path: \(path)")
        }
        if let filename {
            self.logger.debug("Filename: \(filename)")
        }
        self.logger.debug("Action button: \(actionButton)")

        let dialog = try findFileDialogElement()
        var details: [String: String] = [:]

        // Handle path navigation
        if let filePath = path {
            self.logger.debug("Navigating to path using Cmd+Shift+G")

            // Use Go To folder shortcut (Cmd+Shift+G)
            let cmdShiftG = CGEvent(keyboardEventSource: nil, virtualKey: 0x05, keyDown: true) // G
            cmdShiftG?.flags = [.maskCommand, .maskShift]
            cmdShiftG?.post(tap: .cghidEventTap)

            // Wait for go to sheet
            usleep(200_000) // 200ms

            // Type the path
            for char in filePath {
                try self.typeCharacter(char)
                usleep(5000) // 5ms between characters
            }

            // Press Enter
            let enter = CGEvent(keyboardEventSource: nil, virtualKey: 0x24, keyDown: true) // Return
            enter?.post(tap: .cghidEventTap)

            usleep(100_000) // 100ms
            details["path"] = filePath
        }

        // Handle filename
        if let fileName = filename {
            self.logger.debug("Setting filename in dialog")

            // Find the name field (usually the first text field)
            let textFields = self.collectTextFields(from: dialog)
            guard let field = textFields.first else {
                self.logger.error("No text fields found in file dialog")
                throw PeekabooError.operationError(message: "No text fields found in dialog.")
            }

            // Focus and clear the field
            try field.performAction(.press)

            // Select all
            let selectAll = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) // A
            selectAll?.flags = .maskCommand
            selectAll?.post(tap: .cghidEventTap)

            usleep(50000) // 50ms

            // Type the filename
            for char in fileName {
                try self.typeCharacter(char)
                usleep(5000) // 5ms between characters
            }

            details["filename"] = fileName
        }

        // Click the action button
        let buttons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []
        self.logger.debug("Found \(buttons.count) buttons, looking for: \(actionButton)")

        if let button = buttons.first(where: { $0.title() == actionButton }) {
            self.logger.debug("Clicking action button: \(actionButton)")
            try button.performAction(.press)
            details["button_clicked"] = actionButton
        }

        let result = DialogActionResult(
            success: true,
            action: .handleFileDialog,
            details: details)

        self.logger.info("✅ Successfully handled file dialog")
        return result
    }

    public func dismissDialog(force: Bool, windowTitle: String?) async throws -> DialogActionResult {
        self.logger.info("Dismissing dialog (force: \(force))")

        if force {
            self.logger.debug("Force dismissing with Escape key")

            // Press Escape
            let escape = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: true) // Escape
            escape?.post(tap: .cghidEventTap)

            self.logger.info("✅ Dialog dismissed with Escape key")
            return DialogActionResult(
                success: true,
                action: .dismiss,
                details: ["method": "escape"])
        } else {
            self.logger.debug("Looking for dismiss button")

            // Find and click dismiss button
            let dialog = try findDialogElement(withTitle: windowTitle)
            let buttons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []
            self.logger.debug("Found \(buttons.count) buttons in dialog")

            // Look for common dismiss buttons
            let dismissButtons = ["Cancel", "Close", "Dismiss", "No", "Don't Save"]
            self.logger.debug("Looking for dismiss buttons: \(dismissButtons.joined(separator: ", "))")

            for buttonName in dismissButtons {
                if let button = buttons.first(where: { $0.title() == buttonName }) {
                    self.logger.debug("Found dismiss button: \(buttonName)")
                    try button.performAction(.press)

                    self.logger.info("✅ Dialog dismissed by clicking: \(buttonName)")
                    return DialogActionResult(
                        success: true,
                        action: .dismiss,
                        details: [
                            "method": "button",
                            "button": buttonName,
                        ])
                }
            }

            self.logger.error("No dismiss button found in dialog")
            throw PeekabooError.operationError(message: "No dismiss button found in dialog.")
        }
    }

    public func listDialogElements(windowTitle: String?) async throws -> DialogElements {
        self.logger.info("Listing dialog elements")
        if let title = windowTitle {
            self.logger.debug("For window: \(title)")
        }

        // Get dialog info first (this is already properly structured)
        let dialogInfo = try await findActiveDialog(windowTitle: windowTitle)

        // Collect all elements
        let dialog = try findDialogElement(withTitle: windowTitle)

        // Collect buttons
        let axButtons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []
        self.logger.debug("Found \(axButtons.count) buttons")

        let buttons = axButtons.compactMap { btn -> DialogButton? in
            guard let title = btn.title() else { return nil }
            let isEnabled = btn.isEnabled() ?? true
            let isDefault = btn.attribute(Attribute<Bool>("AXDefault")) ?? false

            return DialogButton(
                title: title,
                isEnabled: isEnabled,
                isDefault: isDefault)
        }

        // Collect text fields
        let axTextFields = self.collectTextFields(from: dialog)
        self.logger.debug("Found \(axTextFields.count) text fields")

        let textFields = axTextFields.enumerated().map { index, field in
            DialogTextField(
                title: field.title(),
                value: field.value() as? String,
                placeholder: field.attribute(Attribute<String>("AXPlaceholderValue")),
                index: index,
                isEnabled: field.isEnabled() ?? true)
        }

        // Collect static texts
        let axStaticTexts = dialog.children()?.filter { $0.role() == "AXStaticText" } ?? []
        let staticTexts = axStaticTexts.compactMap { $0.value() as? String }
        self.logger.debug("Found \(staticTexts.count) static texts")

        // Collect other elements
        let otherAxElements = dialog.children()?.filter { element in
            let role = element.role() ?? ""
            return role != "AXButton" && role != "AXTextField" &&
                role != "AXTextArea" && role != "AXStaticText"
        } ?? []

        let otherElements = otherAxElements.compactMap { element -> DialogElement? in
            guard let role = element.role() else { return nil }
            return DialogElement(
                role: role,
                title: element.title(),
                value: element.value() as? String)
        }

        let elements = DialogElements(
            dialogInfo: dialogInfo,
            buttons: buttons,
            textFields: textFields,
            staticTexts: staticTexts,
            otherElements: otherElements)

        self.logger.info("✅ Listed \(buttons.count) buttons, \(textFields.count) fields, \(staticTexts.count) texts")
        return elements
    }

    // MARK: - Private Helpers

    @MainActor
    private func findDialogElement(withTitle title: String?) throws -> Element {
        self.logger.debug("Finding dialog element")

        // Get frontmost application
        let systemWide = Element.systemWide()
        guard let focusedApp = systemWide.attribute(Attribute<Element>("AXFocusedApplication")) else {
            self.logger.error("No focused application found")
            throw PeekabooError.operationError(message: "No active dialog window found.")
        }

        // Look for windows that are likely dialogs
        let windows = focusedApp.windows() ?? []
        self.logger.debug("Checking \(windows.count) windows for dialogs")

        for window in windows {
            let role = window.role() ?? ""
            let subrole = window.subrole() ?? ""

            // Check if it's a dialog-like window
            if role == "AXWindow", subrole == "AXDialog" || subrole == "AXSystemDialog" {
                if let targetTitle = title {
                    if window.title() == targetTitle {
                        self.logger.debug("Found dialog with title: \(targetTitle)")
                        return window
                    }
                } else {
                    self.logger.debug("Found dialog: \(window.title() ?? "Untitled")")
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
    private func findFileDialogElement() throws -> Element {
        // File dialogs often have specific subroles
        let systemWide = Element.systemWide()
        guard let focusedApp = systemWide.attribute(Attribute<Element>("AXFocusedApplication")) else {
            throw PeekabooError.operationError(message: "No active dialog window found.")
        }

        let windows = focusedApp.windows() ?? []

        for window in windows {
            // Check for save/open panels
            if window.role() == "AXWindow" {
                let title = window.title() ?? ""
                if title.contains("Save") || title.contains("Open") ||
                    title.contains("Export") || title.contains("Import")
                {
                    return window
                }
            }
        }

        throw PeekabooError.operationError(message: "No file dialog (Save/Open) found.")
    }

    @MainActor
    private func collectTextFields(from element: Element) -> [Element] {
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

    @MainActor
    private func typeCharacter(_ char: Character) throws {
        // Extended key mapping
        let keyMap: [Character: (CGKeyCode, Bool)] = [
            // Letters
            "a": (0x00, false), "A": (0x00, true),
            "b": (0x0B, false), "B": (0x0B, true),
            "c": (0x08, false), "C": (0x08, true),
            "d": (0x02, false), "D": (0x02, true),
            "e": (0x0E, false), "E": (0x0E, true),
            "f": (0x03, false), "F": (0x03, true),
            "g": (0x05, false), "G": (0x05, true),
            "h": (0x04, false), "H": (0x04, true),
            "i": (0x22, false), "I": (0x22, true),
            "j": (0x26, false), "J": (0x26, true),
            "k": (0x28, false), "K": (0x28, true),
            "l": (0x25, false), "L": (0x25, true),
            "m": (0x2E, false), "M": (0x2E, true),
            "n": (0x2D, false), "N": (0x2D, true),
            "o": (0x1F, false), "O": (0x1F, true),
            "p": (0x23, false), "P": (0x23, true),
            "q": (0x0C, false), "Q": (0x0C, true),
            "r": (0x0F, false), "R": (0x0F, true),
            "s": (0x01, false), "S": (0x01, true),
            "t": (0x11, false), "T": (0x11, true),
            "u": (0x20, false), "U": (0x20, true),
            "v": (0x09, false), "V": (0x09, true),
            "w": (0x0D, false), "W": (0x0D, true),
            "x": (0x07, false), "X": (0x07, true),
            "y": (0x10, false), "Y": (0x10, true),
            "z": (0x06, false), "Z": (0x06, true),

            // Numbers
            "0": (0x1D, false), ")": (0x1D, true),
            "1": (0x12, false), "!": (0x12, true),
            "2": (0x13, false), "@": (0x13, true),
            "3": (0x14, false), "#": (0x14, true),
            "4": (0x15, false), "$": (0x15, true),
            "5": (0x17, false), "%": (0x17, true),
            "6": (0x16, false), "^": (0x16, true),
            "7": (0x1A, false), "&": (0x1A, true),
            "8": (0x1C, false), "*": (0x1C, true),
            "9": (0x19, false), "(": (0x19, true),

            // Special characters
            " ": (0x31, false),
            ".": (0x2F, false),
            ",": (0x2B, false),
            "/": (0x2C, false),
            "\\": (0x2A, false),
            "-": (0x1B, false),
            "_": (0x1B, true),
            "=": (0x18, false),
            "+": (0x18, true),
            ":": (0x29, true),
            ";": (0x29, false),
            "'": (0x27, false),
            "\"": (0x27, true),
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
}
