import AppKit
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
    case fileVerificationFailed(expectedPath: String)
    case fileSavedToUnexpectedDirectory(expectedDirectory: String, actualDirectory: String, actualPath: String)
}

extension DialogError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noActiveDialog:
            "No active dialog window found."
        case .dialogNotFound:
            "Dialog not found."
        case .noFileDialog:
            "No file dialog (Save/Open) found."
        case let .buttonNotFound(name):
            "Button not found: \(name)"
        case .fieldNotFound:
            "Field not found."
        case .invalidFieldIndex:
            "Invalid field index."
        case .noTextFields:
            "No text fields found in dialog."
        case .noDismissButton:
            "No dismiss button found in dialog."
        case let .fileVerificationFailed(expectedPath):
            "Dialog reported success, but the saved file did not appear at: \(expectedPath)"
        case let .fileSavedToUnexpectedDirectory(expectedDirectory, actualDirectory, actualPath):
            "Saved file landed in '\(actualDirectory)', expected '\(expectedDirectory)' (actual: \(actualPath))"
        }
    }
}

/// Default implementation of dialog management operations
@MainActor
public final class DialogService: DialogServiceProtocol {
    let logger = Logger(subsystem: "boo.peekaboo.core", category: "DialogService")
    let dialogTitleHints = ["open", "save", "export", "import", "choose", "replace"]
    let activeDialogSearchTimeout: Float = 0.25
    let targetedDialogSearchTimeout: Float = 0.5
    let applicationService: any ApplicationServiceProtocol
    let focusService = FocusManagementService()
    let windowIdentityService = WindowIdentityService()
    let feedbackClient: any AutomationFeedbackClient
    var scansAllApplicationsForDialogs: Bool {
        ProcessInfo.processInfo.environment["PEEKABOO_DIALOG_SCAN_ALL_APPS"] == "1"
    }

    public init(
        applicationService: (any ApplicationServiceProtocol)? = nil,
        feedbackClient: any AutomationFeedbackClient = NoopAutomationFeedbackClient())
    {
        self.applicationService = applicationService ?? ApplicationService()
        self.feedbackClient = feedbackClient
        self.logger.debug("DialogService initialized")
        // Connect to visual feedback if available.
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.feedbackClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }
}

@MainActor
extension DialogService {
    public func findActiveDialog(windowTitle: String?, appName: String?) async throws -> DialogInfo {
        self.logger.info("Finding active dialog")
        if let title = windowTitle {
            self.logger.debug("Looking for window with title: \(title)")
        }

        let element = try await self.resolveDialogElement(windowTitle: windowTitle, appName: appName)

        let title = element.title() ?? "Untitled Dialog"
        let role = element.role() ?? "Unknown"
        let subrole = element.subrole()

        // Check if it's a file dialog
        let isFileDialog = self.isFileDialogElement(element)

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

    public func clickButton(
        buttonText: String,
        windowTitle: String?,
        appName: String?) async throws -> DialogActionResult
    {
        self.logger.info("Clicking button: \(buttonText)")
        if let title = windowTitle {
            self.logger.debug("In window: \(title)")
        }

        let dialog = try await self.resolveDialogElement(windowTitle: windowTitle, appName: appName)
        return try await self.clickButton(
            in: dialog,
            buttonText: buttonText,
            allowFallbackToDefaultAction: false)
    }

    public func enterText(
        text: String,
        fieldIdentifier: String?,
        clearExisting: Bool,
        windowTitle: String?,
        appName: String?) async throws -> DialogActionResult
    {
        self.logger.info("Entering text into dialog field")
        self.logger.debug("Text length: \(text.count) chars, clear existing: \(clearExisting)")
        if let identifier = fieldIdentifier {
            self.logger.debug("Target field: \(identifier)")
        }

        let dialog = try await self.resolveDialogElement(windowTitle: windowTitle, appName: appName)
        let textFields = self.collectTextFields(from: dialog)
        self.logger.debug("Found \(textFields.count) text fields")

        guard !textFields.isEmpty else {
            self.logger.error("No text fields found in dialog")
            throw DialogError.noTextFields
        }

        let targetField = try self.selectTextField(
            in: textFields,
            identifier: fieldIdentifier)

        await self.highlightDialogElement(
            element: .textField,
            bounds: self.elementBounds(for: targetField),
            action: .enterText)

        self.focusTextField(targetField)
        try self.clearFieldIfNeeded(targetField, shouldClear: clearExisting)
        try self.typeTextValue(text, delay: 10000)

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

    public func dismissDialog(force: Bool, windowTitle: String?, appName: String?) async throws -> DialogActionResult {
        self.logger.info("Dismissing dialog (force: \(force))")

        if force {
            self.logger.debug("Force dismissing with Escape key")

            // Press Escape
            try? InputDriver.tapKey(.escape)

            self.logger.info("\(AgentDisplayTokens.Status.success) Dialog dismissed with Escape key")
            return DialogActionResult(
                success: true,
                action: .dismiss,
                details: ["method": "escape"])
        } else {
            self.logger.debug("Looking for dismiss button")

            // Find and click dismiss button
            let dialog = try await self.resolveDialogElement(windowTitle: windowTitle, appName: appName)
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
            throw DialogError.noDismissButton
        }
    }

    public func listDialogElements(windowTitle: String?, appName: String?) async throws -> DialogElements {
        self.logger.info("Listing dialog elements")
        if let title = windowTitle {
            self.logger.debug("For window: \(title)")
        }

        let dialogInfo = try await findActiveDialog(windowTitle: windowTitle, appName: appName)
        let dialog = try await self.resolveDialogElement(windowTitle: windowTitle, appName: appName)

        let buttons = self.dialogButtons(from: dialog)
        let textFields = self.dialogTextFields(from: dialog)
        let staticTexts = self.dialogStaticTexts(from: dialog)
        let otherElements = self.dialogOtherElements(from: dialog)

        let accessoryRoles: Set = [
            "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXSlider", "AXDisclosureTriangle",
        ]
        let hasAccessoryElements = otherElements.contains { accessoryRoles.contains($0.role) }
        let looksLikeDialog = self.isDialogElement(dialog, matching: windowTitle)
        let hasContent = !buttons.isEmpty ||
            !textFields.isEmpty ||
            !staticTexts.isEmpty ||
            hasAccessoryElements

        let isSuspiciousUnknown = dialogInfo.role == "AXWindow" && dialogInfo.subrole == "AXUnknown"
        if !hasContent, !looksLikeDialog || isSuspiciousUnknown {
            // We landed on a normal window (Finder, Chrome, etc.) and didn't find any dialog-specific
            // controls. Instead of returning an empty payload (which CLI users mistake for success),
            // throw so callers can prompt the user to open the desired sheet first.
            self.logger.error(
                """
                Active window '\(dialogInfo.title)' (role: \(dialogInfo.role)) is not a dialog and \
                contains no interactive elements
                """)
            throw DialogError.noActiveDialog
        }

        let elements = DialogElements(
            dialogInfo: dialogInfo,
            buttons: buttons,
            textFields: textFields,
            staticTexts: staticTexts,
            otherElements: otherElements)

        let summary = "\(AgentDisplayTokens.Status.success) Listed \(buttons.count) buttons, " +
            "\(textFields.count) fields, \(staticTexts.count) texts"
        self.logger.info("\(summary, privacy: .public)")
        return elements
    }
}

// MARK: - Private Helpers

@MainActor
extension DialogService {
    func isSaveLikeAction(_ actionButton: String) -> Bool {
        let normalized = actionButton.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.contains("save") || normalized.contains("export")
    }

    func normalizedDialogButtonTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "...", with: "")
            .lowercased()
    }

    private func dialogButtonTitleMatches(_ candidate: String, requested: String) -> Bool {
        if candidate == requested { return true }
        if candidate.contains(requested) { return true }

        let normalizedCandidate = self.normalizedDialogButtonTitle(candidate)
        let normalizedRequested = self.normalizedDialogButtonTitle(requested)

        if normalizedCandidate == normalizedRequested { return true }
        if normalizedCandidate.contains(normalizedRequested) { return true }

        return false
    }

    private func isCancelLikeButtonTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        let normalized = self.normalizedDialogButtonTitle(title)
        return normalized == "cancel" || normalized == "close" || normalized == "dismiss"
    }

    @MainActor
    private func resolveButton(
        in dialog: Element,
        requestedTitle: String,
        allowFallbackToDefaultAction: Bool) -> Element?
    {
        let buttons = self.collectButtons(from: dialog)
        let identifierAttribute = Attribute<String>("AXIdentifier")
        let normalizedRequested = self.normalizedDialogButtonTitle(requestedTitle)

        if normalizedRequested != "default",
           let match = buttons.first(where: { btn in
               guard let title = btn.title() else { return false }
               return self.dialogButtonTitleMatches(title, requested: requestedTitle)
           })
        {
            return match
        }

        if normalizedRequested == "default",
           let okButton = buttons.first(where: { $0.attribute(identifierAttribute) == "OKButton" })
        {
            return okButton
        }

        if self.isSaveLikeAction(requestedTitle),
           let okButton = buttons.first(where: { $0.attribute(identifierAttribute) == "OKButton" })
        {
            return okButton
        }

        if normalizedRequested == "cancel" || normalizedRequested == "close" || normalizedRequested == "dismiss",
           let cancelButton = buttons.first(where: { $0.attribute(identifierAttribute) == "CancelButton" })
        {
            return cancelButton
        }

        guard allowFallbackToDefaultAction else { return nil }
        if normalizedRequested != "default" {
            guard self.isSaveLikeAction(requestedTitle) else { return nil }
        }

        if let defaultButton = buttons.first(where: { btn in
            (btn.attribute(Attribute<Bool>("AXDefault")) ?? false) && (btn.isEnabled() ?? true)
        }) {
            return defaultButton
        }

        let enabledNonCancel = buttons.filter { btn in
            (btn.isEnabled() ?? true) && !self.isCancelLikeButtonTitle(btn.title())
        }

        if enabledNonCancel.count == 1 {
            return enabledNonCancel[0]
        }

        // Prefer the visually rightmost enabled non-cancel button (common in NSOpenPanel/NSSavePanel).
        let positioned = enabledNonCancel.compactMap { button -> (element: Element, x: CGFloat)? in
            guard let position = button.position() else { return nil }
            return (element: button, x: position.x)
        }
        return positioned.max(by: { $0.x < $1.x })?.element
    }

    func clickButton(
        in dialog: Element,
        buttonText: String,
        allowFallbackToDefaultAction: Bool) async throws -> DialogActionResult
    {
        let buttons = self.collectButtons(from: dialog)
        self.logger.debug("Found \(buttons.count) buttons in dialog")

        guard let targetButton = self.resolveButton(
            in: dialog,
            requestedTitle: buttonText,
            allowFallbackToDefaultAction: allowFallbackToDefaultAction)
        else {
            throw DialogError.buttonNotFound(buttonText)
        }

        let identifierAttribute = Attribute<String>("AXIdentifier")
        let resolvedButtonTitle = targetButton.title() ?? buttonText
        let resolvedButtonIdentifier = targetButton.attribute(identifierAttribute)

        let buttonBounds: CGRect = if let position = targetButton.position(), let size = targetButton.size() {
            CGRect(origin: position, size: size)
        } else {
            .zero
        }

        if buttonBounds != .zero {
            _ = await self.feedbackClient.showDialogInteraction(
                element: .button,
                elementRect: buttonBounds,
                action: .clickButton)
        }

        self.logger.debug("Clicking button: \(resolvedButtonTitle)")
        try self.pressOrClick(targetButton)

        var clickDetails: [String: String] = [
            "button": resolvedButtonTitle,
            "window": dialog.title() ?? "Dialog",
        ]
        if let resolvedButtonIdentifier, !resolvedButtonIdentifier.isEmpty {
            clickDetails["button_identifier"] = resolvedButtonIdentifier
        }

        let result = DialogActionResult(
            success: true,
            action: .clickButton,
            details: clickDetails)

        self.logger
            .info(
                "\(AgentDisplayTokens.Status.success) Successfully clicked button: \(resolvedButtonTitle)")
        return result
    }
}
