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
        }
    }
}

/// Default implementation of dialog management operations
@MainActor
public final class DialogService: DialogServiceProtocol {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "DialogService")
    private let dialogTitleHints = ["open", "save", "export", "import", "choose", "replace"]
    private let applicationService: any ApplicationServiceProtocol
    private let focusService = FocusManagementService()
    private let windowIdentityService = WindowIdentityService()
    private let feedbackClient: any AutomationFeedbackClient

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

    public func handleFileDialog(
        path: String?,
        filename: String?,
        actionButton: String?,
        ensureExpanded: Bool = false,
        appName: String?) async throws -> DialogActionResult
    {
        self.logger.info("Handling file dialog")
        if let path {
            self.logger.debug("Path: \(path)")
        }
        if let filename {
            self.logger.debug("Filename: \(filename)")
        }
        if let actionButton {
            self.logger.debug("Action button: \(actionButton)")
        } else {
            self.logger.debug("Action button: (default/OKButton)")
        }

        let saveStartTime = Date()
        var resolution = try await self.resolveFileDialogElementResolution(appName: appName)
        var dialog = resolution.element
        var details: [String: String] = [
            "dialog_identifier": resolution.dialogIdentifier,
            "found_via": resolution.foundVia,
        ]

        if ensureExpanded {
            try await self.ensureFileDialogExpandedIfNeeded(dialog: dialog)
            // Expanding can rebuild the AX tree; re-resolve.
            resolution = try await self.resolveFileDialogElementResolution(appName: appName)
            dialog = resolution.element
            details["dialog_identifier"] = resolution.dialogIdentifier
            details["found_via"] = resolution.foundVia
            details["ensure_expanded"] = "true"
        }

        if let filePath = path {
            try await self.navigateToPath(filePath, in: dialog, ensureExpanded: ensureExpanded)
            details["path"] = filePath

            // Navigating the path can expand/collapse the panel and rebuild the sheet tree. Re-resolve the active
            // file dialog after navigation so subsequent actions (filename + action button) target fresh AX handles.
            resolution = try await self.resolveFileDialogElementResolution(appName: appName)
            dialog = resolution.element
            details["dialog_identifier"] = resolution.dialogIdentifier
            details["found_via"] = resolution.foundVia
        }

        if let fileName = filename {
            try self.updateFilename(fileName, in: dialog)
            details["filename"] = fileName
        }

        let shouldCapturePriorDocumentPath = actionButton == nil ||
            self.isSaveLikeAction(actionButton ?? "")

        let priorDocumentPath: String? = if shouldCapturePriorDocumentPath {
            self.documentPathForApp(appName: appName)
        } else {
            nil
        }

        // The file panel can swap sheets (e.g. Go to Folder) or rebuild its button tree after typing.
        // Re-resolve the active file dialog right before clicking to avoid stale AX element handles.
        resolution = try await self.resolveFileDialogElementResolution(appName: appName)
        dialog = resolution.element
        details["dialog_identifier"] = resolution.dialogIdentifier
        details["found_via"] = resolution.foundVia

        let requestedButton = actionButton?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRequested = requestedButton.map(self.normalizedDialogButtonTitle)
        let resolvedActionButton: String = if normalizedRequested == "default" || requestedButton == nil {
            "default"
        } else {
            requestedButton ?? "default"
        }

        let clickResult = try await self.clickButton(
            in: dialog,
            buttonText: resolvedActionButton,
            allowFallbackToDefaultAction: true)
        details["button_clicked"] = clickResult.details["button"] ?? resolvedActionButton
        if let buttonIdentifier = clickResult.details["button_identifier"] {
            details["button_identifier"] = buttonIdentifier
        }

        let clickedTitle = clickResult.details["button"] ?? resolvedActionButton
        if self.isSaveLikeAction(clickedTitle) {
            let expectedPath = self.expectedSavedPath(path: path, filename: filename)
            let expectedBaseName = self.expectedSavedBaseName(filename: filename, expectedPath: expectedPath)

            do {
                let verification = try await self.verifySavedFile(SavedFileVerificationRequest(
                    appName: appName,
                    priorDocumentPath: priorDocumentPath,
                    expectedPath: expectedPath,
                    expectedBaseName: expectedBaseName,
                    startedAt: saveStartTime,
                    timeout: 5.0))

                details["saved_path"] = verification.path
                details["saved_path_exists"] = "true"
                details["saved_path_verified"] = "true"
                details["saved_path_found_via"] = verification.foundVia

                if let expectedPath {
                    details["saved_path_matches_expected"] = String(verification.path == expectedPath)
                    if verification.path != expectedPath {
                        details["saved_path_expected"] = expectedPath
                    }
                }
            } catch let error as DialogError {
                guard case .fileVerificationFailed = error else { throw error }
                let didReplace = await self.clickReplaceIfPresent(appName: appName)
                guard didReplace else { throw error }

                let retryStart = Date()
                let verification = try await self.verifySavedFile(SavedFileVerificationRequest(
                    appName: appName,
                    priorDocumentPath: priorDocumentPath,
                    expectedPath: expectedPath,
                    expectedBaseName: expectedBaseName,
                    startedAt: retryStart,
                    timeout: 5.0))

                details["saved_path"] = verification.path
                details["saved_path_exists"] = "true"
                details["saved_path_verified"] = "true"
                details["saved_path_found_via"] = verification.foundVia
                details["overwrite_confirmed"] = "true"

                if let expectedPath {
                    details["saved_path_matches_expected"] = String(verification.path == expectedPath)
                    if verification.path != expectedPath {
                        details["saved_path_expected"] = expectedPath
                    }
                }
            }
        }

        let result = DialogActionResult(
            success: true,
            action: .handleFileDialog,
            details: details)

        self.logger.info("\(AgentDisplayTokens.Status.success) Successfully handled file dialog")
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

        let accessoryRoles: Set<String> = [
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
    private func isSaveLikeAction(_ actionButton: String) -> Bool {
        let normalized = actionButton.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.contains("save") || normalized.contains("export")
    }

    private func fallbackFindRecentlyWrittenFile(preferredPath: String, startedAt: Date) -> String? {
        let preferredURL = URL(fileURLWithPath: preferredPath)
        let baseName = preferredURL.deletingPathExtension().lastPathComponent
        return self.fallbackFindRecentlyWrittenFile(filenamePrefix: baseName, startedAt: startedAt)
    }

    private func fallbackFindRecentlyWrittenFile(filename: String, startedAt: Date) -> String? {
        let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        return self.fallbackFindRecentlyWrittenFile(filenamePrefix: baseName, startedAt: startedAt)
    }

    private func fallbackFindRecentlyWrittenFile(filenamePrefix: String, startedAt: Date) -> String? {
        let fileManager = FileManager.default

        let candidates: [URL] = [
            URL(fileURLWithPath: "/private/tmp"),
            URL(fileURLWithPath: "/tmp"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
            URL(fileURLWithPath: fileManager.currentDirectoryPath),
        ]
            .map(\.standardizedFileURL)
            .filter { fileManager.fileExists(atPath: $0.path) }

        for directory in candidates {
            if let match = self.findRecentlyWrittenFile(
                in: directory,
                fileNamePrefix: filenamePrefix,
                startedAt: startedAt)
            {
                return match
            }
        }

        return nil
    }

    private func normalizedDialogButtonTitle(_ title: String) -> String {
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

    private func clickButton(
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

    private func expectedSavedPath(path: String?, filename: String?) -> String? {
        guard let filename else { return nil }
        guard let path else { return nil }

        let expandedPath = (path as NSString).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expandedPath).standardizedFileURL

        if baseURL.lastPathComponent == filename {
            return baseURL.path
        }

        return baseURL.appendingPathComponent(filename).path
    }

    private struct SavedFileVerification {
        let path: String
        let foundVia: String
    }

    private struct SavedFileVerificationRequest {
        let appName: String?
        let priorDocumentPath: String?
        let expectedPath: String?
        let expectedBaseName: String?
        let startedAt: Date
        let timeout: TimeInterval
    }

    private func expectedSavedBaseName(filename: String?, expectedPath: String?) -> String? {
        if let filename {
            return URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        }
        if let expectedPath {
            return URL(fileURLWithPath: expectedPath).deletingPathExtension().lastPathComponent
        }
        return nil
    }

    private func verifySavedFile(_ request: SavedFileVerificationRequest) async throws -> SavedFileVerification {
        let deadline = request.startedAt.addingTimeInterval(request.timeout)
        let fileManager = FileManager.default

        let expectedURL = request.expectedPath.map { URL(fileURLWithPath: $0) }
        let expectedDirectory = expectedURL?.deletingLastPathComponent()
        let expectedFileBaseName = expectedURL?.deletingPathExtension().lastPathComponent

        var lastDirectoryScan: Date?

        while Date() < deadline {
            if let appName = request.appName,
               let current = self.documentPathForApp(appName: appName)
            {
                let matchesName: Bool = if let expectedBaseName = request.expectedBaseName {
                    URL(fileURLWithPath: current).deletingPathExtension().lastPathComponent.hasPrefix(expectedBaseName)
                } else {
                    true
                }

                if matchesName,
                   fileManager.fileExists(atPath: current),
                   self.fileWasModified(atPath: current, since: request.startedAt)
                {
                    return SavedFileVerification(path: current, foundVia: "document_path")
                }

                if matchesName,
                   let priorDocumentPath = request.priorDocumentPath,
                   current != priorDocumentPath,
                   fileManager.fileExists(atPath: current)
                {
                    return SavedFileVerification(path: current, foundVia: "document_path")
                }
            }

            if let expectedPath = request.expectedPath,
               fileManager.fileExists(atPath: expectedPath)
            {
                return SavedFileVerification(path: expectedPath, foundVia: "expected_path")
            }

            let shouldScanDirectory = lastDirectoryScan == nil ||
                Date().timeIntervalSince(lastDirectoryScan ?? Date.distantPast) > 0.5

            if shouldScanDirectory,
               let expectedDirectory,
               let expectedBaseName = expectedFileBaseName ?? request.expectedBaseName,
               let candidate = self.findRecentlyWrittenFile(
                   in: expectedDirectory,
                   fileNamePrefix: expectedBaseName,
                   startedAt: request.startedAt)
            {
                return SavedFileVerification(path: candidate, foundVia: "expected_directory_scan")
            }

            if shouldScanDirectory {
                lastDirectoryScan = Date()
            }

            try await Task.sleep(nanoseconds: 125_000_000)
        }

        if let expectedBaseName = request.expectedBaseName,
           let fallback = self.fallbackFindRecentlyWrittenFile(
               filenamePrefix: expectedBaseName,
               startedAt: request.startedAt)
        {
            return SavedFileVerification(path: fallback, foundVia: "fallback_search")
        }

        let expectedDescription: String = if let expectedPath = request.expectedPath {
            expectedPath
        } else if let expectedBaseName = request.expectedBaseName {
            "(unknown directory; name prefix: \(expectedBaseName))"
        } else {
            "(unknown path)"
        }

        throw DialogError.fileVerificationFailed(expectedPath: expectedDescription)
    }

    private func findRecentlyWrittenFile(
        in directory: URL,
        fileNamePrefix: String,
        startedAt: Date) -> String?
    {
        let fileManager = FileManager.default

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])
        else {
            return nil
        }

        let earliest = startedAt.addingTimeInterval(-2.0)

        let candidates: [(url: URL, modifiedAt: Date)] = urls.compactMap { url in
            guard url.lastPathComponent.hasPrefix(fileNamePrefix) else { return nil }
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? Date.distantPast
            guard modifiedAt >= earliest else { return nil }
            return (url: url, modifiedAt: modifiedAt)
        }

        guard let best = candidates.max(by: { $0.modifiedAt < $1.modifiedAt }) else {
            return nil
        }

        return best.url.path
    }

    private func findDialogElement(withTitle title: String?, appName: String?) throws -> Element {
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

        var focusedAppElement: Element? = systemWide.attribute(Attribute<Element>("AXFocusedApplication")) ?? {
            if let frontmost = NSWorkspace.shared.frontmostApplication {
                return AXApp(frontmost).element
            }
            return nil
        }()

        // Always prefer an explicit app hint over whatever currently has system-wide focus.
        if let appName,
           let targetApp = self.runningApplication(matching: appName)
        {
            focusedAppElement = AXApp(targetApp).element
        }

        guard let focusedApp = focusedAppElement else {
            self.logger.error("No focused application found")
            throw DialogError.noActiveDialog
        }

        let windows = focusedApp.windowsWithTimeout() ?? []
        self.logger.debug("Checking \(windows.count) windows for dialogs")

        for window in windows {
            if let candidate = self.resolveDialogCandidate(in: window, matching: title) {
                return candidate
            }
        }

        if let globalWindows = systemWide.windows() {
            for window in globalWindows {
                if let candidate = self.resolveDialogCandidate(in: window, matching: title) {
                    return candidate
                }
            }
        }

        for app in NSWorkspace.shared.runningApplications {
            let axApp = AXApp(app).element
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

    private func resolveDialogElement(windowTitle: String?, appName: String?) async throws -> Element {
        if let appName, !appName.isEmpty {
            self.logger.debug("Resolving dialog with app hint: \(appName)")
        }
        if let element = try? self.findDialogElement(withTitle: windowTitle, appName: appName) {
            return element
        }

        await self.ensureDialogVisibility(windowTitle: windowTitle, appName: appName)

        if let element = try? self.findDialogElement(withTitle: windowTitle, appName: appName) {
            return element
        }

        if let element = await self.findDialogViaApplicationService(windowTitle: windowTitle, appName: appName) {
            return element
        }

        if windowTitle == nil,
           let appName,
           let fileDialog = self.findActiveFileDialogElement(appName: appName)
        {
            return fileDialog
        }

        throw DialogError.noActiveDialog
    }

    private func resolveFileDialogElement(appName: String?) async throws -> Element {
        if let appName,
           let fileDialog = self.findActiveFileDialogElement(appName: appName)
        {
            return fileDialog
        }

        let element = try await self.resolveDialogElement(windowTitle: nil, appName: appName)
        guard self.isFileDialogElement(element) else {
            throw DialogError.noFileDialog
        }
        return element
    }

    @MainActor
    private func findActiveFileDialogElement(appName: String) -> Element? {
        guard let targetApp = self.runningApplication(matching: appName) else { return nil }
        let appElement = AXApp(targetApp).element

        let windows = appElement.windowsWithTimeout() ?? []
        for window in windows {
            if let candidate = self.findActiveFileDialogCandidate(in: window) {
                return candidate
            }
        }
        return nil
    }

    @MainActor
    private func findActiveFileDialogCandidate(in element: Element) -> Element? {
        if self.isFileDialogElement(element) {
            return element
        }

        for sheet in self.sheetElements(for: element) {
            if let candidate = self.findActiveFileDialogCandidate(in: sheet) {
                return candidate
            }
        }

        if let children = element.children() {
            for child in children {
                if let candidate = self.findActiveFileDialogCandidate(in: child) {
                    return candidate
                }
            }
        }

        return nil
    }

    private func ensureDialogVisibility(windowTitle: String?, appName: String?) async {
        do {
            let applications = try await self.applicationService.listApplications()
            for app in applications.data.applications {
                if let appName,
                   app.name.caseInsensitiveCompare(appName) != .orderedSame,
                   app.bundleIdentifier?.caseInsensitiveCompare(appName) != .orderedSame
                {
                    continue
                }

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
                            bringToCurrentSpace: true))
                    try await Task.sleep(nanoseconds: 200_000_000)
                    return
                }
            }
        } catch {
            self.logger.debug("Dialog visibility assist failed: \(String(describing: error))")
        }
    }

    @MainActor
    private func findDialogViaApplicationService(windowTitle: String?, appName: String?) async -> Element? {
        guard let applications = try? await self.applicationService.listApplications() else {
            return nil
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let frontmostBundle = frontmostApp?.bundleIdentifier?.lowercased()
        let frontmostName = frontmostApp?.localizedName?.lowercased()

        for app in applications.data.applications {
            if let appName,
               app.name.caseInsensitiveCompare(appName) != .orderedSame,
               app.bundleIdentifier?.caseInsensitiveCompare(appName) != .orderedSame
            {
                continue
            }

            if let bundle = frontmostBundle,
               let candidateBundle = app.bundleIdentifier?.lowercased(),
               candidateBundle != bundle
            {
                continue
            }

            if frontmostBundle == nil,
               let name = frontmostName,
               app.name.lowercased() != name
            {
                continue
            }

            guard let windowsOutput = try? await self.applicationService.listWindows(for: app.name, timeout: nil) else {
                continue
            }

            guard let windowInfo = windowsOutput.data.windows.first(where: {
                self.matchesDialogWindowTitle($0.title, expectedTitle: windowTitle)
            }) else {
                continue
            }

            if let windowHandle = self.windowIdentityService.findWindow(byID: CGWindowID(windowInfo.windowID)),
               let candidate = self.resolveDialogCandidate(
                   in: windowHandle.element,
                   matching: windowTitle ?? windowInfo.title)
            {
                return candidate
            }

            guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else { continue }
            let axApp = AXApp(runningApp).element
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

    private func selectTextField(in textFields: [Element], identifier: String?) throws -> Element {
        guard let identifier else {
            return textFields[0]
        }

        if let index = Int(identifier) {
            guard textFields.indices.contains(index) else {
                throw DialogError.invalidFieldIndex
            }
            return textFields[index]
        }

        guard let field = textFields.first(where: { field in
            field.title() == identifier ||
                field.attribute(Attribute<String>("AXPlaceholderValue")) == identifier ||
                field.descriptionText()?.contains(identifier) == true
        }) else {
            throw DialogError.fieldNotFound
        }

        return field
    }

    private func elementBounds(for element: Element) -> CGRect {
        guard let position = element.position(), let size = element.size() else {
            return .zero
        }
        return CGRect(origin: position, size: size)
    }

    private func highlightDialogElement(
        element: DialogElementType,
        bounds: CGRect,
        action: DialogActionType) async
    {
        guard bounds != .zero else { return }
        _ = await self.feedbackClient.showDialogInteraction(
            element: element,
            elementRect: bounds,
            action: action)
    }

    private func focusTextField(_ field: Element) {
        let elementDescription = field.briefDescription(option: ValueFormatOption.smart)
        self.logger.debug("Focusing text field: \(elementDescription)")

        if field.isAttributeSettable(named: AXAttributeNames.kAXFocusedAttribute),
           field.setValue(true, forAttribute: AXAttributeNames.kAXFocusedAttribute)
        {
            return
        }

        if field.isActionSupported(AXActionNames.kAXPressAction) {
            do {
                try field.performAction(.press)
                return
            } catch {
                self.logger.debug("Failed to focus text field via press: \(String(describing: error))")
            }
        }

        if let position = field.position(),
           let size = field.size(),
           size.width > 0,
           size.height > 0
        {
            let point = CGPoint(x: position.x + size.width / 2.0, y: position.y + size.height / 2.0)
            try? InputDriver.click(at: point)
            return
        }

        self.logger.debug("Text field is not focusable (focused attribute not settable; press/click unavailable).")
    }

    private func clearFieldIfNeeded(_ field: Element, shouldClear: Bool) throws {
        guard shouldClear else { return }
        self.logger.debug("Clearing existing text")
        try? InputDriver.hotkey(keys: ["cmd", "a"])
        try? InputDriver.tapKey(.delete)
        usleep(50000)
    }

    private func typeTextValue(_ text: String, delay: useconds_t) throws {
        self.logger.debug("Typing text into field")
        try InputDriver.type(text, delayPerCharacter: Double(delay) / 1_000_000.0)
    }

    private func pressKey(_ virtualKey: CGKeyCode, modifiers: CGEventFlags = []) {
        if let special = self.mapSpecialKey(code: virtualKey) {
            var keys = self.modifierKeys(from: modifiers)
            keys.append(special)
            try? InputDriver.hotkey(keys: keys, holdDuration: 0.05)
            return
        }
        if let character = self.mapCharacter(code: virtualKey) {
            var keys = self.modifierKeys(from: modifiers)
            keys.append(character)
            try? InputDriver.hotkey(keys: keys, holdDuration: 0.05)
            return
        }
    }

    private func mapSpecialKey(code: CGKeyCode) -> String? {
        switch code {
        case 0x24: "return"
        case 0x35: "escape"
        case 0x33: "delete"
        case 0x30: "tab"
        default: nil
        }
    }

    private func mapCharacter(code: CGKeyCode) -> String? {
        let mapping: [CGKeyCode: String] = [
            0x00: "a",
            0x05: "g",
        ]
        return mapping[code]
    }

    private func modifierKeys(from flags: CGEventFlags) -> [String] {
        var keys: [String] = []
        if flags.contains(.maskCommand) { keys.append("cmd") }
        if flags.contains(.maskShift) { keys.append("shift") }
        if flags.contains(.maskAlternate) { keys.append("alt") }
        if flags.contains(.maskControl) { keys.append("ctrl") }
        if flags.contains(.maskSecondaryFn) { keys.append("fn") }
        return keys
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

    private func dialogButtons(from dialog: Element) -> [DialogButton] {
        let axButtons = self.collectButtons(from: dialog)
        self.logger.debug("Found \(axButtons.count) buttons")

        return axButtons.compactMap { btn -> DialogButton? in
            guard let title = btn.title() else { return nil }
            let isEnabled = btn.isEnabled() ?? true
            let isDefault = btn.attribute(Attribute<Bool>("AXDefault")) ?? false

            return DialogButton(
                title: title,
                isEnabled: isEnabled,
                isDefault: isDefault)
        }
    }

    private func dialogTextFields(from dialog: Element) -> [DialogTextField] {
        let axTextFields = self.collectTextFields(from: dialog)
        self.logger.debug("Found \(axTextFields.count) text fields")

        return axTextFields.indexed().map { index, field in
            DialogTextField(
                title: field.title(),
                value: field.value() as? String,
                placeholder: field.attribute(Attribute<String>("AXPlaceholderValue")),
                index: index,
                isEnabled: field.isEnabled() ?? true)
        }
    }

    private func dialogStaticTexts(from dialog: Element) -> [String] {
        let axStaticTexts = dialog.children()?.filter { $0.role() == "AXStaticText" } ?? []
        let staticTexts = axStaticTexts.compactMap { $0.value() as? String }
        self.logger.debug("Found \(staticTexts.count) static texts")
        return staticTexts
    }

    private func dialogOtherElements(from dialog: Element) -> [DialogElement] {
        let otherAxElements = dialog.children()?.filter { element in
            let role = element.role() ?? ""
            return role != "AXButton" && role != "AXTextField" &&
                role != "AXTextArea" && role != "AXStaticText"
        } ?? []

        return otherAxElements.compactMap { element -> DialogElement? in
            guard let role = element.role() else { return nil }
            return DialogElement(
                role: role,
                title: element.title(),
                value: element.value() as? String)
        }
    }

    @MainActor
    private func findFirstDescendant(
        in element: Element,
        identifierAttribute: Attribute<String>,
        identifierContains: String) -> Element?
    {
        let identifier = element.attribute(identifierAttribute) ?? ""
        if identifier.localizedCaseInsensitiveContains(identifierContains) {
            return element
        }

        for sheet in self.sheetElements(for: element) {
            if let match = self.findFirstDescendant(
                in: sheet,
                identifierAttribute: identifierAttribute,
                identifierContains: identifierContains)
            {
                return match
            }
        }

        if let children = element.children() {
            for child in children {
                if let match = self.findFirstDescendant(
                    in: child,
                    identifierAttribute: identifierAttribute,
                    identifierContains: identifierContains)
                {
                    return match
                }
            }
        }

        return nil
    }

    private func navigateToPath(_ filePath: String, in dialog: Element, ensureExpanded: Bool) async throws {
        let expandedPath = (filePath as NSString).expandingTildeInPath
        let targetURL = URL(fileURLWithPath: expandedPath)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

        let directoryPath: String = if exists, !isDirectory.boolValue {
            targetURL.deletingLastPathComponent().path
        } else if !targetURL.pathExtension.isEmpty {
            targetURL.deletingLastPathComponent().path
        } else {
            expandedPath
        }

        try await self.navigateToDirectory(directoryPath: directoryPath, in: dialog, ensureExpanded: ensureExpanded)
    }

    private func navigateToDirectory(directoryPath: String, in dialog: Element, ensureExpanded: Bool) async throws {
        let identifierAttribute = Attribute<String>("AXIdentifier")
        let pathFieldIdentifier = "PathTextField"

        func findPathField(in element: Element) -> Element? {
            self.collectTextFields(from: element).first(where: { field in
                field.attribute(identifierAttribute) == pathFieldIdentifier
            })
        }

        var pathField = findPathField(in: dialog)

        if ensureExpanded || pathField == nil {
            try await self.ensureFileDialogExpandedIfNeeded(dialog: dialog)
            pathField = findPathField(in: dialog)
        }

        guard let pathField else {
            // Fallback: Cmd+Shift+G (Go to Folder) is the most reliable way to land in an arbitrary directory.
            self.logger.debug("No PathTextField found; falling back to Go to Folder (Cmd+Shift+G)")
            try? InputDriver.hotkey(keys: ["cmd", "shift", "g"], holdDuration: 0.05)
            try await Task.sleep(nanoseconds: 200_000_000)
            try? InputDriver.hotkey(keys: ["cmd", "a"], holdDuration: 0.05)
            try self.typeTextValue(directoryPath, delay: 5000)
            try InputDriver.tapKey(.return)
            try await Task.sleep(nanoseconds: 250_000_000)
            return
        }

        self.focusTextField(pathField)
        if pathField.isAttributeSettable(named: AXAttributeNames.kAXValueAttribute),
           pathField.setValue(directoryPath, forAttribute: AXAttributeNames.kAXValueAttribute)
        {
            // Some NSSavePanel implementations don't update AXValue immediately; commit via Return below.
        } else {
            try? InputDriver.hotkey(keys: ["cmd", "a"], holdDuration: 0.05)
            try self.typeTextValue(directoryPath, delay: 5000)
        }
        try InputDriver.tapKey(.return)
        try await Task.sleep(nanoseconds: 250_000_000)
    }

    private func ensureFileDialogExpandedIfNeeded(dialog: Element) async throws {
        let identifierAttribute = Attribute<String>("AXIdentifier")

        func findDisclosureCandidate(in element: Element) -> Element? {
            if element.role() == "AXDisclosureTriangle" {
                return element
            }

            let identifier = element.attribute(identifierAttribute) ?? ""
            if identifier.localizedCaseInsensitiveContains("DISCLOSURE_TRIANGLE") ||
                identifier.localizedCaseInsensitiveContains("DISCLOSURE") ||
                identifier.localizedCaseInsensitiveContains("ShowDetails") ||
                identifier.localizedCaseInsensitiveContains("HideDetails")
            {
                return element
            }

            let title = (element.title() ?? "").lowercased()
            if title.contains("show details") || title.contains("hide details") {
                return element
            }

            let description = (element.attribute(Attribute<String>("AXDescription")) ?? "").lowercased()
            if description.contains("show details") || description.contains("hide details") {
                return element
            }

            for sheet in self.sheetElements(for: element) {
                if let match = findDisclosureCandidate(in: sheet) {
                    return match
                }
            }

            if let children = element.children() {
                for child in children {
                    if let match = findDisclosureCandidate(in: child) {
                        return match
                    }
                }
            }

            return nil
        }

        guard let disclosure = findDisclosureCandidate(in: dialog) else { return }

        // Only click if it appears to be collapsed, or if we can't infer state (we'll still try once).
        let title = (disclosure.title() ?? "").lowercased()
        let description = (disclosure.attribute(Attribute<String>("AXDescription")) ?? "").lowercased()
        let shouldClick = title.contains("show details") ||
            description.contains("show details") ||
            (title.isEmpty && description.isEmpty)
        guard shouldClick else { return }

        try self.pressOrClick(disclosure)
        try await Task.sleep(nanoseconds: 250_000_000)
    }

    private func dialogIdentifier(for element: Element) -> String {
        let role = element.role() ?? "unknown"
        let subrole = element.subrole() ?? ""
        let title = element.title() ?? "Untitled Dialog"
        let axIdentifier = element.attribute(Attribute<String>("AXIdentifier")) ?? ""

        return [role, subrole, axIdentifier, title]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
    }

    private func resolveFileDialogElementResolution(appName: String?) async throws
    -> (element: Element, dialogIdentifier: String, foundVia: String) {
        if let appName,
           let fileDialog = self.findActiveFileDialogElement(appName: appName)
        {
            return (
                element: fileDialog,
                dialogIdentifier: self.dialogIdentifier(for: fileDialog),
                foundVia: "active_file_dialog")
        }

        let resolved = try await self.resolveDialogElementResolution(windowTitle: nil, appName: appName)
        guard self.isFileDialogElement(resolved.element) else {
            throw DialogError.noFileDialog
        }

        return resolved
    }

    private func resolveDialogElementResolution(
        windowTitle: String?,
        appName: String?) async throws -> (element: Element, dialogIdentifier: String, foundVia: String)
    {
        if let appName, !appName.isEmpty {
            self.logger.debug("Resolving dialog with app hint: \(appName)")
        }

        if let element = try? self.findDialogElement(withTitle: windowTitle, appName: appName) {
            return (
                element: element,
                dialogIdentifier: self.dialogIdentifier(for: element),
                foundVia: "find_dialog_element")
        }

        await self.ensureDialogVisibility(windowTitle: windowTitle, appName: appName)

        if let element = try? self.findDialogElement(withTitle: windowTitle, appName: appName) {
            return (
                element: element,
                dialogIdentifier: self.dialogIdentifier(for: element),
                foundVia: "ensure_visibility_then_find")
        }

        if let element = await self.findDialogViaApplicationService(windowTitle: windowTitle, appName: appName) {
            return (
                element: element,
                dialogIdentifier: self.dialogIdentifier(for: element),
                foundVia: "application_service")
        }

        if windowTitle == nil,
           let appName,
           let fileDialog = self.findActiveFileDialogElement(appName: appName)
        {
            return (
                element: fileDialog,
                dialogIdentifier: self.dialogIdentifier(for: fileDialog),
                foundVia: "active_file_dialog_fallback")
        }

        throw DialogError.noActiveDialog
    }

    @MainActor
    private func clickReplaceIfPresent(appName: String?) async -> Bool {
        guard let dialog = try? await self.resolveDialogElement(windowTitle: nil, appName: appName) else {
            return false
        }

        let buttons = self.collectButtons(from: dialog)
        guard let replace = buttons.first(where: { btn in
            guard let title = btn.title() else { return false }
            return self.dialogButtonTitleMatches(title, requested: "Replace")
        }) else {
            return false
        }

        do {
            try self.pressOrClick(replace)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    private func documentPathForApp(appName: String?) -> String? {
        guard let appName, let running = self.runningApplication(matching: appName) else { return nil }
        let appElement = AXApp(running).element

        let windows = appElement.windowsWithTimeout() ?? []
        let preferredWindows: [Element] = [
            appElement.mainWindow(),
            appElement.focusedWindow(),
        ].compactMap(\.self)

        let candidates = (preferredWindows + windows)

        func isDialogLike(_ window: Element) -> Bool {
            let subrole = window.subrole() ?? ""
            if subrole == "AXDialog" || subrole == "AXSystemDialog" || subrole == "AXAlert" { return true }

            let roleDescription = window.attribute(Attribute<String>("AXRoleDescription")) ?? ""
            if roleDescription.localizedCaseInsensitiveContains("dialog") { return true }

            let identifier = window.attribute(Attribute<String>("AXIdentifier")) ?? ""
            if identifier.contains("NSOpenPanel") || identifier.contains("NSSavePanel") { return true }

            return false
        }

        for window in candidates where !isDialogLike(window) {
            let document = window.attribute(Attribute<String>(AXAttributeNames.kAXDocumentAttribute))
            if let normalized = self.normalizeDocumentAttributeToPath(document) {
                return normalized
            }
        }

        return nil
    }

    @MainActor
    private func normalizeDocumentAttributeToPath(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }

        if raw.hasPrefix("file://"),
           let url = URL(string: raw),
           url.isFileURL
        {
            return url.path
        }

        return raw
    }

    private func fileWasModified(atPath path: String, since date: Date) -> Bool {
        guard let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.contentModificationDateKey]),
              let modifiedAt = values.contentModificationDate
        else {
            return false
        }

        return modifiedAt >= date.addingTimeInterval(-2.0)
    }

    private func pressOrClick(_ element: Element) throws {
        do {
            try element.performAction(.press)
            return
        } catch {
            guard let position = element.position(),
                  let size = element.size(),
                  size.width > 0,
                  size.height > 0
            else {
                throw error
            }

            let point = CGPoint(x: position.x + size.width / 2.0, y: position.y + size.height / 2.0)
            try InputDriver.click(at: point)
        }
    }

    private func updateFilename(_ fileName: String, in dialog: Element) throws {
        self.logger.debug("Setting filename in dialog")
        let textFields = self.collectTextFields(from: dialog)
        guard !textFields.isEmpty else {
            self.logger.error("No text fields found in file dialog")
            throw DialogError.noTextFields
        }

        let expectedBaseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent.lowercased()
        let identifierAttribute = Attribute<String>("AXIdentifier")

        func fieldScore(_ field: Element) -> Int {
            let title = (field.title() ?? "").lowercased()
            let placeholder = (field.attribute(Attribute<String>("AXPlaceholderValue")) ?? "").lowercased()
            let description = (field.attribute(Attribute<String>("AXDescription")) ?? "").lowercased()
            let identifier = (field.attribute(identifierAttribute) ?? "").lowercased()
            let combined = "\(title) \(placeholder) \(description) \(identifier)"

            if combined.contains("tags") { return 100 }
            if combined.contains("save") ||
                combined.contains("file name") ||
                combined.contains("filename") ||
                combined.contains("name")
            {
                return 0
            }

            let value = (field.value() as? String) ?? ""
            if !value.isEmpty { return 10 }
            return 50
        }

        let fieldsToTry: [Element] = if let saveAsField = textFields.first(where: { field in
            field.attribute(identifierAttribute) == "saveAsNameTextField"
        }) {
            [saveAsField]
        } else {
            textFields
                .filter { $0.isEnabled() ?? true }
                .compactMap { field -> (field: Element, score: Int, position: CGPoint)? in
                    guard let position = field.position() else { return nil }
                    return (field: field, score: fieldScore(field), position: position)
                }
                .sorted(by: { lhs, rhs in
                    if lhs.score != rhs.score { return lhs.score < rhs.score }
                    if lhs.position.y != rhs.position.y { return lhs.position.y < rhs.position.y }
                    return lhs.position.x < rhs.position.x
                })
                .map(\.field)
        }

        for (index, field) in fieldsToTry.indexed() {
            self.focusTextField(field)
            if field.isAttributeSettable(named: AXAttributeNames.kAXValueAttribute),
               field.setValue(fileName, forAttribute: AXAttributeNames.kAXValueAttribute)
            {
                // Commit below by sending a small delay; some panels apply filename changes lazily.
            } else {
                try? InputDriver.hotkey(keys: ["cmd", "a"], holdDuration: 0.05)
                usleep(75000)
                try self.typeTextValue(fileName, delay: 5000)
            }
            usleep(150_000)

            if let updatedValue = field.value() as? String {
                let actualBaseName = URL(fileURLWithPath: updatedValue)
                    .deletingPathExtension()
                    .lastPathComponent
                    .lowercased()
                if actualBaseName == expectedBaseName || actualBaseName.hasPrefix(expectedBaseName) {
                    self.logger.debug("Filename set using text field index \(index)")
                    return
                }
            }

            // Many NSSavePanel implementations (including TextEdit) do not reliably expose the live text field
            // contents via AXValue. If we successfully focused a plausible field and typed the name, treat the
            // attempt as best-effort and continue the flow; the subsequent save verification will catch failures.
            if index == 0 {
                self.logger.debug(
                    "Typed filename into first candidate text field; proceeding without AXValue confirmation")
                return
            }
        }

        self.logger.debug(
            "Typed filename into \(fieldsToTry.count) candidate text fields; proceeding without AXValue confirmation")
    }

    private func matchesDialogWindowTitle(_ title: String, expectedTitle: String?) -> Bool {
        if let expectedTitle, !expectedTitle.isEmpty {
            return title.localizedCaseInsensitiveContains(expectedTitle)
        }
        return self.dialogTitleHints.contains { title.localizedCaseInsensitiveContains($0) }
    }

    private func runningApplication(matching identifier: String) -> NSRunningApplication? {
        let lowered = identifier.lowercased()
        return NSWorkspace.shared.runningApplications.first {
            if let name = $0.localizedName?.lowercased(),
               name == lowered || name.contains(lowered)
            {
                return true
            }
            if let bundle = $0.bundleIdentifier?.lowercased(),
               bundle == lowered || bundle.contains(lowered)
            {
                return true
            }
            return false
        }
    }

    @MainActor
    private func findDialogUsingCGWindowList(title: String?) -> Element? {
        guard let cgWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID) as? [[String: Any]]
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

            guard let appElement = AXApp(pid: pid_t(ownerPid.intValue))?.element,
                  let windows = appElement.windowsWithTimeout()
            else { continue }

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
        if let attachedSheets = element.sheets() {
            sheets.append(contentsOf: attachedSheets)
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

        if subrole == "AXDialog" || subrole == "AXSystemDialog" || subrole == "AXAlert" {
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

        // Some apps expose sheets as AXWindow/AXUnknown instead of AXSheet. Avoid treating every AXUnknown
        // window as a dialog (TextEdit's main document window can be AXUnknown), and instead require at
        // least one dialog-ish signal.
        if subrole == "AXUnknown" {
            let buttonTitles = Set(self.collectButtons(from: element).compactMap { $0.title()?.lowercased() })
            let hasCancel = buttonTitles.contains("cancel")
            let hasDialogButton = hasCancel ||
                buttonTitles.contains("ok") ||
                buttonTitles.contains("open") ||
                buttonTitles.contains("save") ||
                buttonTitles.contains("choose") ||
                buttonTitles.contains("replace") ||
                buttonTitles.contains("export") ||
                buttonTitles.contains("import") ||
                buttonTitles.contains("don't save")

            if hasDialogButton {
                return true
            }
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

        if self.dialogTitleHints.contains(where: { windowTitle.localizedCaseInsensitiveContains($0) }) {
            return true
        }

        // Some sheets (e.g. TextEdit's Save sheet) expose no useful title/identifier but do expose canonical buttons.
        let buttons = self.collectButtons(from: element)
        let buttonTitles = Set(buttons.compactMap { $0.title()?.lowercased() })
        let buttonIdentifiers = Set(buttons.compactMap { $0.attribute(Attribute<String>("AXIdentifier")) })

        let hasCancel = buttonTitles.contains("cancel") || buttonIdentifiers.contains("CancelButton")
        let hasPrimaryTitle = ["save", "open", "choose", "replace", "export", "import"]
            .contains { buttonTitles.contains($0) }
        let hasPrimaryIdentifier = buttonIdentifiers.contains("OKButton")

        return hasCancel && (hasPrimaryTitle || hasPrimaryIdentifier)
    }

    @MainActor
    func typeCharacter(_ char: Character) throws {
        try DialogService.typeCharacterHandler(String(char))
    }
}

#if DEBUG
extension DialogService {
    /// Test hook to override character typing without sending real events.
    static var typeCharacterHandler: (String) throws -> Void = { text in
        try InputDriver.type(text, delayPerCharacter: 0)
    }
}
#else
extension DialogService {
    fileprivate static var typeCharacterHandler: (String) throws -> Void { { text in try InputDriver.type(
        text,
        delayPerCharacter: 0) } }
}
#endif
