import AppKit
import AXorcist
import Foundation
import PeekabooFoundation

@MainActor
extension DialogService {
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

        await self.ensureDialogFocus(dialog: dialog, appName: appName)

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
            let navigation = try await self.navigateToPath(
                filePath,
                in: dialog,
                ensureExpanded: ensureExpanded,
                appName: appName)
            details["path"] = filePath
            details["path_navigation_method"] = navigation

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
                let verification = try await self.verifySavedFile(
                    SavedFileVerificationRequest(
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

                try self.enforceExpectedDirectoryIfNeeded(
                    actualSavedPath: verification.path,
                    expectedPath: expectedPath,
                    details: &details)
            } catch let error as DialogError {
                guard case .fileVerificationFailed = error else { throw error }
                let didReplace = await self.clickReplaceIfPresent(appName: appName)
                guard didReplace else { throw error }

                let retryStart = Date()
                let verification = try await self.verifySavedFile(
                    SavedFileVerificationRequest(
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

                try self.enforceExpectedDirectoryIfNeeded(
                    actualSavedPath: verification.path,
                    expectedPath: expectedPath,
                    details: &details)
            }
        }

        let result = DialogActionResult(
            success: true,
            action: .handleFileDialog,
            details: details)

        self.logger.info("\(AgentDisplayTokens.Status.success) Successfully handled file dialog")
        return result
    }

    private func enforceExpectedDirectoryIfNeeded(
        actualSavedPath: String,
        expectedPath: String?,
        details: inout [String: String]) throws
    {
        guard let expectedPath else { return }
        let expectedDirectory = URL(fileURLWithPath: expectedPath)
            .deletingLastPathComponent()
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let actualDirectory = URL(fileURLWithPath: actualSavedPath)
            .deletingLastPathComponent()
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        details["saved_path_expected_directory"] = expectedDirectory
        details["saved_path_directory"] = actualDirectory
        details["saved_path_matches_expected_directory"] = String(expectedDirectory == actualDirectory)

        guard expectedDirectory == actualDirectory else {
            throw DialogError.fileSavedToUnexpectedDirectory(
                expectedDirectory: expectedDirectory,
                actualDirectory: actualDirectory,
                actualPath: actualSavedPath)
        }
    }
}

@MainActor
extension DialogService {
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

    private func expectedSavedPath(path: String?, filename: String?) -> String? {
        guard let filename else { return nil }
        guard let path else { return nil }

        let expandedPath = (path as NSString).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expandedPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()

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
                    URL(fileURLWithPath: current)
                        .deletingPathExtension()
                        .lastPathComponent
                        .hasPrefix(expectedBaseName)
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

    private func clickReplaceIfPresent(appName: String?) async -> Bool {
        guard let dialog = try? await self.resolveDialogElement(windowTitle: nil, appName: appName) else {
            return false
        }

        let buttons = self.collectButtons(from: dialog)
        guard let replace = buttons.first(where: { btn in
            let normalized = (btn.title() ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "…", with: "")
                .replacingOccurrences(of: "...", with: "")
                .lowercased()
            return normalized == "replace" || normalized.contains("replace")
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

    private func navigateToPath(
        _ filePath: String,
        in dialog: Element,
        ensureExpanded: Bool,
        appName: String?) async throws -> String
    {
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

        return try await self.navigateToDirectory(
            directoryPath: directoryPath,
            in: dialog,
            ensureExpanded: ensureExpanded,
            appName: appName)
    }

    private func navigateToDirectory(
        directoryPath: String,
        in dialog: Element,
        ensureExpanded: Bool,
        appName: String?) async throws -> String
    {
        let identifierAttribute = Attribute<String>("AXIdentifier")
        let pathFieldIdentifier = "PathTextField"

        func findPathField(in element: Element) -> Element? {
            self.collectTextFields(from: element).first(where: { field in
                field.attribute(identifierAttribute) == pathFieldIdentifier
            })
        }

        var pathField = findPathField(in: dialog)

        if ensureExpanded {
            try await self.ensureFileDialogExpandedIfNeeded(dialog: dialog)
            pathField = findPathField(in: dialog)
        }

        await self.ensureDialogFocus(dialog: dialog, appName: appName)

        let requestedDirectory = URL(fileURLWithPath: directoryPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        guard let pathField else {
            try await self.navigateViaGoToFolder(directoryPath: requestedDirectory, dialog: dialog, appName: appName)
            return "go_to_folder"
        }

        var method = "path_textfield"

        self.focusTextField(pathField)
        if pathField.isAttributeSettable(named: AXAttributeNames.kAXValueAttribute),
           pathField.setValue(requestedDirectory, forAttribute: AXAttributeNames.kAXValueAttribute)
        {
            // Some NSSavePanel implementations don't update AXValue immediately; commit via Return below.
            method = "path_textfield_axvalue"
        } else {
            try? InputDriver.hotkey(keys: ["cmd", "a"], holdDuration: 0.05)
            try await Task.sleep(nanoseconds: 75_000_000)
            try self.typeTextValue(requestedDirectory, delay: 5000)
            method = "path_textfield_typed"
        }
        try InputDriver.tapKey(.return)
        try await Task.sleep(nanoseconds: 250_000_000)

        let rawValue = pathField.value() as? String
        if let rawValue, !rawValue.isEmpty {
            let actualDirectory = URL(fileURLWithPath: rawValue)
                .standardizedFileURL
                .resolvingSymlinksInPath()
                .path
            if actualDirectory != requestedDirectory {
                self.logger.debug(
                    "PathTextField mismatch; Go to Folder. requested: \(requestedDirectory), actual: \(actualDirectory)"
                )
                try await self.navigateViaGoToFolder(
                    directoryPath: requestedDirectory,
                    dialog: dialog,
                    appName: appName)
                method += "+fallback_go_to_folder"
            }
        } else {
            self.logger.debug("PathTextField did not expose an AXValue; falling back to Go to Folder")
            try await self.navigateViaGoToFolder(
                directoryPath: requestedDirectory,
                dialog: dialog,
                appName: appName)
            method += "+fallback_go_to_folder"
        }

        return method
    }

    private func ensureDialogFocus(dialog: Element, appName: String?) async {
        guard let appName, let running = self.runningApplication(matching: appName) else {
            self.clickDialogCenterIfPossible(dialog)
            return
        }

        if NSWorkspace.shared.frontmostApplication?.processIdentifier != running.processIdentifier {
            _ = running.activate(options: [.activateAllWindows])
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        self.clickDialogCenterIfPossible(dialog)
    }

    private func clickDialogCenterIfPossible(_ dialog: Element) {
        guard let position = dialog.position(),
              let size = dialog.size(),
              size.width > 0,
              size.height > 0
        else {
            return
        }

        let point = CGPoint(x: position.x + size.width / 2.0, y: position.y + size.height / 2.0)
        try? InputDriver.click(at: point)
    }

    private func navigateViaGoToFolder(directoryPath: String, dialog: Element, appName: String?) async throws {
        await self.ensureDialogFocus(dialog: dialog, appName: appName)
        self.logger.debug("Navigating via Go to Folder (Cmd+Shift+G): \(directoryPath)")

        try? InputDriver.hotkey(keys: ["cmd", "shift", "g"], holdDuration: 0.05)
        try await Task.sleep(nanoseconds: 250_000_000)

        // Best effort: re-assert focus before typing into the Go-to sheet.
        await self.ensureDialogFocus(dialog: dialog, appName: appName)

        try? InputDriver.hotkey(keys: ["cmd", "a"], holdDuration: 0.05)
        try await Task.sleep(nanoseconds: 75_000_000)
        try self.typeTextValue(directoryPath, delay: 5000)
        try InputDriver.tapKey(.return)
        try await Task.sleep(nanoseconds: 450_000_000)
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
}
