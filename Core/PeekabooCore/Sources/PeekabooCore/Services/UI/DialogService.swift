import AppKit
import ApplicationServices
import AXorcist
import Foundation
import os.log
import PeekabooFoundation

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
    private let dialogTitleHints = ["open", "save", "export", "import", "choose", "replace"]
    private let applicationService: any ApplicationServiceProtocol
    private let focusService = FocusManagementService()

    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared

    public init(applicationService: (any ApplicationServiceProtocol)? = nil) {
        self.applicationService = applicationService ?? ApplicationService()
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

        let element = try await self.resolveDialogElement(windowTitle: windowTitle)

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

        self.logger.info("\(AgentDisplayTokens.Status.success) Found dialog: \(title), file dialog: \(isFileDialog)")
        return info
    }

    public func clickButton(buttonText: String, windowTitle: String?) async throws -> DialogActionResult {
        self.logger.info("Clicking button: \(buttonText)")
        if let title = windowTitle {
            self.logger.debug("In window: \(title)")
        }

        let dialog = try await self.resolveDialogElement(windowTitle: windowTitle)

        // Find buttons
        let buttons = self.collectButtons(from: dialog)
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
                element: .button,
                elementRect: buttonBounds,
                action: .clickButton)
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

        self.logger
            .info(
                "\(AgentDisplayTokens.Status.success) Successfully clicked button: \(targetButton.title() ?? buttonText)")
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

        let dialog = try await self.resolveDialogElement(windowTitle: windowTitle)

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
                element: .textField,
                elementRect: fieldBounds,
                action: .enterText)
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

        self.logger.info("\(AgentDisplayTokens.Status.success) Successfully entered text into field")
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

        await self.ensureDialogVisibility(windowTitle: nil)
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
        let buttons = self.collectButtons(from: dialog)
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

        self.logger.info("\(AgentDisplayTokens.Status.success) Successfully handled file dialog")
        return result
    }

    public func dismissDialog(force: Bool, windowTitle: String?) async throws -> DialogActionResult {
        self.logger.info("Dismissing dialog (force: \(force))")

        if force {
            self.logger.debug("Force dismissing with Escape key")

            // Press Escape
            let escape = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: true) // Escape
            escape?.post(tap: .cghidEventTap)

            self.logger.info("\(AgentDisplayTokens.Status.success) Dialog dismissed with Escape key")
            return DialogActionResult(
                success: true,
                action: .dismiss,
                details: ["method": "escape"])
        } else {
            self.logger.debug("Looking for dismiss button")

            // Find and click dismiss button
            let dialog = try await self.resolveDialogElement(windowTitle: windowTitle)
            let buttons = dialog.children()?.filter { $0.role() == "AXButton" } ?? []
            self.logger.debug("Found \(buttons.count) buttons in dialog")

            // Look for common dismiss buttons
            let dismissButtons = ["Cancel", "Close", "Dismiss", "No", "Don't Save"]
            self.logger.debug("Looking for dismiss buttons: \(dismissButtons.joined(separator: ", "))")

            for buttonName in dismissButtons {
                if let button = buttons.first(where: { $0.title() == buttonName }) {
                    self.logger.debug("Found dismiss button: \(buttonName)")
                    try button.performAction(.press)

                    self.logger.info("\(AgentDisplayTokens.Status.success) Dialog dismissed by clicking: \(buttonName)")
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
        let dialog = try await self.resolveDialogElement(windowTitle: windowTitle)

        // Collect buttons
        let axButtons = self.collectButtons(from: dialog)
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

        self.logger
            .info(
                "\(AgentDisplayTokens.Status.success) Listed \(buttons.count) buttons, \(textFields.count) fields, \(staticTexts.count) texts")
        return elements
    }

    // MARK: - Private Helpers

    @MainActor
    private func findDialogElement(withTitle title: String?) throws -> Element {
        self.logger.debug("Finding dialog element")

        let systemWide = Element.systemWide()

        if let focusedElement = systemWide.attribute(Attribute<Element>("AXFocusedUIElement")),
           let hostingWindow = focusedElement.attribute(Attribute<Element>("AXWindow")),
           let candidate = self.resolveDialogCandidate(in: hostingWindow, matching: title)
        {
            return candidate
        }

        if let focusedWindow = systemWide.attribute(Attribute<Element>("AXFocusedWindow")),
           let focusedCandidate = self.resolveDialogCandidate(in: focusedWindow, matching: title)
        {
            return focusedCandidate
        }

        guard let focusedApp = systemWide.attribute(Attribute<Element>("AXFocusedApplication")) else {
            self.logger.error("No focused application found")
            throw PeekabooError.operationError(message: "No active dialog window found.")
        }

        let windows = focusedApp.windowsWithTimeout() ?? []
        self.logger.debug("Checking \(windows.count) windows for dialogs")

        for window in windows {
            if let candidate = self.resolveDialogCandidate(in: window, matching: title) {
                return candidate
            }
        }

        if let globalWindows: [AXUIElement] = systemWide.attribute(Attribute<[AXUIElement]>("AXWindows")) {
            for rawWindow in globalWindows {
                let element = Element(rawWindow)
                if let candidate = self.resolveDialogCandidate(in: element, matching: title) {
                    return candidate
                }
            }
        }

        for app in NSWorkspace.shared.runningApplications {
            let axApp = Element(AXUIElementCreateApplication(app.processIdentifier))
            let appWindows = axApp.windowsWithTimeout() ?? []
            for window in appWindows {
                if let candidate = self.resolveDialogCandidate(in: window, matching: title) {
                    return candidate
                }
            }
        }

        if let cgCandidate = self.findDialogUsingCGWindowList(title: title) {
            return cgCandidate
        }

        throw DialogError.noActiveDialog
    }

    private func resolveDialogElement(windowTitle: String?) async throws -> Element {
        if let element = try? self.findDialogElement(withTitle: windowTitle) {
            return element
        }

        await self.ensureDialogVisibility(windowTitle: windowTitle)

        if let element = try? self.findDialogElement(withTitle: windowTitle) {
            return element
        }

        if let element = await self.findDialogViaApplicationService(windowTitle: windowTitle) {
            return element
        }

        throw DialogError.noActiveDialog
    }

    private func ensureDialogVisibility(windowTitle: String?) async {
        do {
            let applications = try await self.applicationService.listApplications()
            for app in applications.data.applications {
                let windowsOutput = try await self.applicationService.listWindows(for: app.name, timeout: nil)
                if let window = windowsOutput.data.windows.first(where: {
                    self.matchesDialogWindowTitle($0.title, expectedTitle: windowTitle)
                }) {
                    self.logger.info("Focusing dialog candidate '\(window.title)' from \(app.name)")
                    try await self.focusService.focusWindow(
                        windowID: CGWindowID(window.windowID),
                        options: FocusManagementService.FocusOptions(
                            timeout: 1.0,
                            retryCount: 1,
                            switchSpace: true,
                            bringToCurrentSpace: true)
                    )
                    try await Task.sleep(nanoseconds: 200_000_000)
                    return
                }
            }
        } catch {
            self.logger.debug("Dialog visibility assist failed: \(String(describing: error))")
        }
    }

    @MainActor
    private func findDialogViaApplicationService(windowTitle: String?) async -> Element? {
        guard let applications = try? await self.applicationService.listApplications() else {
            return nil
        }

        for app in applications.data.applications {
            guard let windowsOutput = try? await self.applicationService.listWindows(for: app.name, timeout: nil) else {
                continue
            }

            guard let windowInfo = windowsOutput.data.windows.first(where: {
                self.matchesDialogWindowTitle($0.title, expectedTitle: windowTitle)
            }) else {
                continue
            }

            let axApp = Element(AXUIElementCreateApplication(app.processIdentifier))
            guard let appWindows = axApp.windowsWithTimeout() else { continue }

            if let match = appWindows.first(where: {
                let title = $0.title() ?? ""
                return title == windowInfo.title ||
                    self.matchesDialogWindowTitle(title, expectedTitle: windowTitle)
            }) {
                return match
            }
        }

        return nil
    }

    @MainActor
    private func findFileDialogElement() throws -> Element {
        let systemWide = Element.systemWide()
        guard let focusedApp = systemWide.attribute(Attribute<Element>("AXFocusedApplication")) else {
            throw PeekabooError.operationError(message: "No active dialog window found.")
        }

        let windows = focusedApp.windows() ?? []

        for window in windows {
            if let candidate = self.resolveDialogCandidate(in: window, matching: nil),
               self.isFileDialogElement(candidate)
            {
                return candidate
            }
        }

        if let focusedWindow = systemWide.attribute(Attribute<Element>("AXFocusedWindow")),
           self.isFileDialogElement(focusedWindow)
        {
            return focusedWindow
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
    private func collectButtons(from element: Element) -> [Element] {
        var buttons: [Element] = []

        func collect(from el: Element) {
            if el.role() == "AXButton" {
                buttons.append(el)
            }

            if let children = el.children() {
                for child in children {
                    collect(from: child)
                }
            }
        }

        collect(from: element)
        return buttons
    }

    private func matchesDialogWindowTitle(_ title: String, expectedTitle: String?) -> Bool {
        if let expectedTitle, !expectedTitle.isEmpty {
            return title.localizedCaseInsensitiveContains(expectedTitle)
        }
        return self.dialogTitleHints.contains { title.localizedCaseInsensitiveContains($0) }
    }

    @MainActor
    private func findDialogUsingCGWindowList(title: String?) -> Element? {
        guard let cgWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]
        else {
            return nil
        }

        for info in cgWindows {
            guard let ownerPid = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let windowTitle = (info[kCGWindowName as String] as? String) ?? ""

            if let expectedTitle = title,
               !windowTitle.localizedCaseInsensitiveContains(expectedTitle)
            {
                continue
            }

            if title == nil,
               !self.dialogTitleHints.contains(where: { windowTitle.localizedCaseInsensitiveContains($0) })
            {
                continue
            }

            let appElement = Element(AXUIElementCreateApplication(pid_t(ownerPid.intValue)))
            guard let windows = appElement.windowsWithTimeout() else { continue }

            if let matchingWindow = windows.first(where: {
                let axTitle = $0.title() ?? ""
                return axTitle == windowTitle || self.isDialogElement($0, matching: title)
            }) {
                return matchingWindow
            }
        }

        return nil
    }

    @MainActor
    private func resolveDialogCandidate(in element: Element, matching title: String?) -> Element? {
        if self.isDialogElement(element, matching: title) {
            return element
        }

        for sheet in self.sheetElements(for: element) {
            if let candidate = self.resolveDialogCandidate(in: sheet, matching: title) {
                return candidate
            }
        }

        if let children = element.children() {
            for child in children {
                if let candidate = self.resolveDialogCandidate(in: child, matching: title) {
                    return candidate
                }
            }
        }

        return nil
    }

    @MainActor
    private func sheetElements(for element: Element) -> [Element] {
        var sheets: [Element] = []
        if let children = element.children() {
            sheets.append(contentsOf: children.filter { $0.role() == "AXSheet" })
        }
        if let axSheets: [AXUIElement] = element.attribute(Attribute<[AXUIElement]>("AXSheets")) {
            sheets.append(contentsOf: axSheets.map(Element.init))
        }
        return sheets
    }

    @MainActor
    private func isDialogElement(_ element: Element, matching title: String?) -> Bool {
        let role = element.role() ?? ""
        let subrole = element.subrole() ?? ""
        let roleDescription = element.attribute(Attribute<String>("AXRoleDescription")) ?? ""
        let identifier = element.attribute(Attribute<String>("AXIdentifier")) ?? ""
        let windowTitle = element.title() ?? ""

        if let expectedTitle = title, !windowTitle.elementsEqual(expectedTitle) {
            return false
        }

        if role == "AXSheet" || role == "AXDialog" {
            return true
        }

        if subrole == "AXDialog" || subrole == "AXSystemDialog" || subrole == "AXAlert" ||
            subrole == "AXUnknown"
        {
            return true
        }

        if roleDescription.localizedCaseInsensitiveContains("dialog") {
            return true
        }

        if identifier.contains("NSOpenPanel") || identifier.contains("NSSavePanel") {
            return true
        }

        if self.dialogTitleHints.contains(where: { windowTitle.localizedCaseInsensitiveContains($0) }) {
            return true
        }

        return false
    }

    @MainActor
    private func isFileDialogElement(_ element: Element) -> Bool {
        let identifier = element.attribute(Attribute<String>("AXIdentifier")) ?? ""
        let windowTitle = element.title() ?? ""

        if identifier.contains("NSOpenPanel") || identifier.contains("NSSavePanel") {
            return true
        }

        return self.dialogTitleHints.contains {
            windowTitle.localizedCaseInsensitiveContains($0)
        }
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
