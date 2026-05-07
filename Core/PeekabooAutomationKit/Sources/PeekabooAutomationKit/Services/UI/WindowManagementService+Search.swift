import AppKit
import AXorcist
import Foundation
import PeekabooFoundation

@MainActor
extension WindowManagementService {
    func findWindowByTitle(_ titleSubstring: String, in apps: [ServiceApplicationInfo]) throws -> Element {
        self.logger.info("Searching for window with title containing: '\(titleSubstring)' in \(apps.count) apps")
        let startTime = Date()

        if let frontmostWindow = self.findWindowInFrontmostApp(
            titleSubstring: titleSubstring,
            apps: apps,
            startTime: startTime)
        {
            return frontmostWindow
        }

        return try self.searchAllApplications(
            titleSubstring: titleSubstring,
            apps: apps,
            startTime: startTime)
    }

    func findWindowByTitleInApp(_ titleSubstring: String, app: ServiceApplicationInfo) throws -> Element {
        self.logger.info("Searching for window with title containing: '\(titleSubstring)' in app: \(app.name)")

        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw NotFoundError.application(app.name)
        }
        let appElement = AXApp(runningApp).element

        guard let windows = appElement.windows() else {
            throw NotFoundError.window(app: app.name)
        }

        for window in windows {
            if let title = window.title(),
               title.localizedCaseInsensitiveContains(titleSubstring)
            {
                self.logger.info("Found window '\(title)' in app '\(app.name)'")
                return window
            }
        }

        throw PeekabooError.windowNotFound(criteria: "title containing '\(titleSubstring)' in app '\(app.name)'")
    }

    func findWindowInFrontmostApp(
        titleSubstring: String,
        apps: [ServiceApplicationInfo],
        startTime: Date) -> Element?
    {
        guard let frontmostApp = apps.first(where: { app in
            NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        }) else {
            return nil
        }

        self.logger.debug("Checking frontmost app first: \(frontmostApp.name)")
        guard let runningApp = NSRunningApplication(processIdentifier: frontmostApp.processIdentifier)
        else { return nil }
        let appElement = AXApp(runningApp).element

        guard let windows = appElement.windows() else { return nil }
        for window in windows where window.title()?.localizedCaseInsensitiveContains(titleSubstring) == true {
            let elapsed = Date().timeIntervalSince(startTime)
            self.logger.info("Found window in frontmost app after \(elapsed)s")
            return window
        }

        return nil
    }

    func searchAllApplications(
        titleSubstring: String,
        apps: [ServiceApplicationInfo],
        startTime: Date) throws -> Element
    {
        var searchedApps = 0
        var totalWindows = 0

        for app in apps {
            searchedApps += 1

            if self.shouldSkipSystemApp(app) {
                continue
            }

            guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else { continue }
            let appElement = AXApp(runningApp).element

            guard let windows = appElement.windows() else { continue }
            totalWindows += windows.count

            if searchedApps % 5 == 0 {
                let elapsed = Date().timeIntervalSince(startTime)
                self.logger.debug("Searched \(searchedApps) apps, \(totalWindows) windows so far (\(elapsed)s)")
            }

            let context = WindowSearchContext(
                appName: app.name,
                searchedApps: searchedApps,
                totalWindows: totalWindows,
                startTime: startTime)

            if let match = self.windowMatchingTitle(titleSubstring, in: windows, context: context) {
                return match
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        self.logger
            .error("Window not found after searching \(searchedApps) apps and \(totalWindows) windows (\(elapsed)s)")
        throw PeekabooError.windowNotFound()
    }

    func shouldSkipSystemApp(_ app: ServiceApplicationInfo) -> Bool {
        app.name.hasPrefix("com.apple.") &&
            !["Safari", "Mail", "Notes", "Terminal", "Finder"].contains(app.name)
    }

    func windowMatchingTitle(
        _ titleSubstring: String,
        in windows: [Element],
        context: WindowSearchContext) -> Element?
    {
        for window in windows where window.title()?.localizedCaseInsensitiveContains(titleSubstring) == true {
            let elapsed = Date().timeIntervalSince(context.startTime)
            let message = self.buildWindowFoundMessage(
                windowTitle: window.title() ?? "",
                context: context,
                elapsed: elapsed)
            self.logger.info("\(message, privacy: .public)")
            return window
        }
        return nil
    }

    func buildWindowFoundMessage(
        windowTitle: String,
        context: WindowSearchContext,
        elapsed: TimeInterval) -> String
    {
        [
            "Found window '\(windowTitle)' in app '\(context.appName)'",
            "after searching \(context.searchedApps) apps and \(context.totalWindows) windows (\(elapsed)s)",
        ].joined(separator: " ")
    }
}

struct WindowSearchContext {
    let appName: String
    let searchedApps: Int
    let totalWindows: Int
    let startTime: Date
}
