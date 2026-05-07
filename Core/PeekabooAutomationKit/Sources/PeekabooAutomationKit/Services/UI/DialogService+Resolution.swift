import AppKit
import AXorcist
import CoreGraphics
import Foundation

@MainActor
extension DialogService {
    func resolveDialogElement(windowTitle: String?, appName: String?) async throws -> Element {
        if let appName, !appName.isEmpty {
            self.logger.debug("Resolving dialog with app hint: \(appName)")
        }
        if let element = try? self.findDialogElement(withTitle: windowTitle, appName: appName) {
            return element
        }

        if windowTitle != nil {
            await self.ensureDialogVisibility(windowTitle: windowTitle, appName: appName)
            if let element = try? self.findDialogElement(withTitle: windowTitle, appName: appName) {
                return element
            }

            if let element = await self.findDialogViaApplicationService(windowTitle: windowTitle, appName: appName) {
                return element
            }
        }

        throw DialogError.noActiveDialog
    }

    func resolveFileDialogElementResolution(appName: String?) async throws
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

    func runningApplication(matching identifier: String) -> NSRunningApplication? {
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

        let windowSearchTimeout = self.dialogWindowSearchTimeout(title: title, appName: appName)
        let windows = self.dialogWindowCandidates(in: focusedApp, title: title, appName: appName)
        self.logger.debug("Checking \(windows.count) windows for dialogs")

        for window in windows {
            if let candidate = self.resolveDialogCandidate(in: window, matching: title) {
                return candidate
            }
        }

        if title != nil {
            if let globalWindows = systemWide.windows() {
                for window in globalWindows {
                    if let candidate = self.resolveDialogCandidate(in: window, matching: title) {
                        return candidate
                    }
                }
            }
        }

        if self.scansAllApplicationsForDialogs {
            for app in NSWorkspace.shared.runningApplications {
                let axApp = AXApp(app).element
                let appWindows = axApp.windowsWithTimeout(timeout: windowSearchTimeout) ?? []
                for window in appWindows {
                    if let candidate = self.resolveDialogCandidate(in: window, matching: title) {
                        return candidate
                    }
                }
            }
        }

        if title != nil, let cgCandidate = self.findDialogUsingCGWindowList(title: title) {
            return cgCandidate
        }

        throw DialogError.noActiveDialog
    }

    private func dialogWindowSearchTimeout(title: String?, appName: String?) -> Float {
        title != nil || appName != nil ? self.targetedDialogSearchTimeout : self.activeDialogSearchTimeout
    }

    private func dialogWindowCandidates(in app: Element, title: String?, appName: String?) -> [Element] {
        let timeout = self.dialogWindowSearchTimeout(title: title, appName: appName)

        // Without a title, an app-scoped command is still looking for the active dialog, not every dialog-like
        // subtree in the app. Checking focused/main windows keeps "no dialog" responses bounded for Electron/Tauri.
        if appName != nil, title == nil {
            app.setMessagingTimeout(timeout)
            defer { app.setMessagingTimeout(0) }
            return [
                app.focusedWindow(),
                app.mainWindow(),
            ].compactMap(\.self)
        }

        return app.windowsWithTimeout(timeout: timeout) ?? []
    }

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
        guard windowTitle != nil || appName != nil else {
            return
        }

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
            guard let appWindows = axApp.windowsWithTimeout(timeout: 0.5) else { continue }

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

        if windowTitle != nil {
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
        }

        throw DialogError.noActiveDialog
    }

    private func matchesDialogWindowTitle(_ title: String, expectedTitle: String?) -> Bool {
        if let expectedTitle, !expectedTitle.isEmpty {
            return title.localizedCaseInsensitiveContains(expectedTitle)
        }
        return self.dialogTitleHints.contains { title.localizedCaseInsensitiveContains($0) }
    }

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
                  let windows = appElement.windowsWithTimeout(timeout: 0.5)
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

    private func resolveDialogCandidate(in element: Element, matching title: String?) -> Element? {
        if self.isDialogElement(element, matching: title) {
            return element
        }

        let sheets = title == nil ? (element.sheets() ?? []) : self.sheetElements(for: element)
        for sheet in sheets {
            if let candidate = self.resolveDialogCandidate(in: sheet, matching: title) {
                return candidate
            }
        }

        guard title != nil else {
            return nil
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
}
