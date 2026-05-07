import AppKit
import AXorcist
import CoreGraphics
import Foundation
import PeekabooFoundation

@MainActor
extension WindowManagementService {
    /// Performs a window operation within MainActor context.
    func performWindowOperation<T: Sendable>(
        target: WindowTarget,
        operation: @MainActor (Element) -> T) async throws -> T
    {
        let window = try await self.element(for: target)
        return operation(window)
    }

    func windows(for appIdentifier: String) async throws -> [ServiceWindowInfo] {
        let output = try await self.applicationService.listWindows(for: appIdentifier, timeout: nil)
        return output.data.windows
    }

    func windowsWithTitleSubstring(_ substring: String) async throws -> [ServiceWindowInfo] {
        let appsOutput = try await self.applicationService.listApplications()
        var matches: [ServiceWindowInfo] = []

        for app in appsOutput.data.applications {
            let windows = try await self.windows(for: app.name)
            matches.append(contentsOf: windows.filter {
                $0.title.localizedCaseInsensitiveContains(substring)
            })
        }
        return matches
    }

    func windowById(_ id: Int) async throws -> [ServiceWindowInfo] {
        if let windowInfo = self.cgInfoLookup.serviceWindowInfo(windowID: id) {
            return [windowInfo]
        }

        let appsOutput = try await self.applicationService.listApplications()
        for app in appsOutput.data.applications {
            let windows = try await self.windows(for: app.name)
            if let window = windows.first(where: { $0.windowID == id }) {
                return [window]
            }
        }
        throw PeekabooError.windowNotFound()
    }

    func element(for target: WindowTarget) async throws -> Element {
        switch target {
        case let .application(appIdentifier):
            let app = try await self.applicationService.findApplication(identifier: appIdentifier)
            return try self.findFirstWindow(for: app)
        case let .title(titleSubstring):
            let appsOutput = try await self.applicationService.listApplications()
            return try self.findWindowByTitle(titleSubstring, in: appsOutput.data.applications)
        case let .applicationAndTitle(appIdentifier, titleSubstring):
            let app = try await self.applicationService.findApplication(identifier: appIdentifier)

            if let windowFromID = try await self.findWindowByTitleUsingWindowID(
                titleSubstring: titleSubstring,
                appIdentifier: appIdentifier,
                app: app)
            {
                return windowFromID
            }

            return try self.findWindowByTitleInApp(titleSubstring, app: app)
        case let .index(appIdentifier, index):
            let app = try await self.applicationService.findApplication(identifier: appIdentifier)
            return try self.findWindowByIndex(for: app, index: index)
        case .frontmost:
            let frontmostApp = try await self.applicationService.getFrontmostApplication()
            return try self.findFirstWindow(for: frontmostApp)
        case let .windowId(id):
            if let handle = self.windowIdentityService.findWindow(byID: CGWindowID(id)) {
                return handle.element
            }

            let appsOutput = try await self.applicationService.listApplications()
            return try self.findWindowById(id, in: appsOutput.data.applications)
        }
    }

    func findFirstWindow(for app: ServiceApplicationInfo) throws -> Element {
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw NotFoundError.application(app.name)
        }
        let appElement = AXApp(runningApp).element

        guard let windows = appElement.windows(), !windows.isEmpty else {
            throw NotFoundError.window(app: app.name)
        }

        if let renderable = self.firstRenderableWindow(from: windows, appName: app.name) {
            return renderable
        }

        self.logger.debug("Falling back to first AX window for \(app.name); no renderable window detected")
        return windows[0]
    }

    func findWindowByIndex(for app: ServiceApplicationInfo, index: Int) throws -> Element {
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw NotFoundError.application(app.name)
        }
        let appElement = AXApp(runningApp).element

        guard let windows = appElement.windows() else {
            throw NotFoundError.window(app: app.name)
        }

        guard index >= 0, index < windows.count else {
            throw PeekabooError.invalidInput(
                "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count - 1)")
        }

        return windows[index]
    }

    func firstRenderableWindow(from windows: [Element], appName: String) -> Element? {
        let minimumDimension: CGFloat = 50

        for (idx, window) in windows.indexed() {
            if window.isMinimized() == true {
                self.logger.debug("Skipping minimized window idx \(idx) for \(appName)")
                continue
            }

            guard
                let size = window.size(),
                size.width >= minimumDimension,
                size.height >= minimumDimension,
                let position = window.position()
            else {
                self.logger.debug("Skipping tiny window idx \(idx) for \(appName)")
                continue
            }

            let bounds = CGRect(origin: position, size: size)
            guard bounds.width >= minimumDimension, bounds.height >= minimumDimension else {
                self.logger.debug("Skipping non-renderable window idx \(idx) for \(appName)")
                continue
            }

            self.logger.debug(
                "Selected renderable window idx \(idx) for \(appName) with bounds \(String(describing: bounds))")
            return window
        }

        return nil
    }

    func findWindowByTitleUsingWindowID(
        titleSubstring: String,
        appIdentifier: String,
        app: ServiceApplicationInfo) async throws -> Element?
    {
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw NotFoundError.application(app.name)
        }

        let windows = try await self.windows(for: appIdentifier)
        guard let match = windows.first(where: { $0.title.localizedCaseInsensitiveContains(titleSubstring) }) else {
            return nil
        }

        let windowID = CGWindowID(match.windowID)
        if let handle = self.windowIdentityService.findWindow(byID: windowID, in: runningApp) {
            return handle.element
        }

        // AXWindowResolver couldn't find it, fall back to scanning the app's AX windows by CGWindowID.
        return try self.findWindowById(Int(windowID), in: [app])
    }

    func findWindowById(_ id: Int, in apps: [ServiceApplicationInfo]) throws -> Element {
        for app in apps {
            guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else { continue }
            let appElement = AXApp(runningApp).element

            guard let windows = appElement.windows() else { continue }
            for window in windows {
                if let windowID = self.windowIdentityService.getWindowID(from: window),
                   Int(windowID) == id
                {
                    self.logger.debug("Matched window id \(id) in app \(app.name)")
                    return window
                }
            }
        }

        throw PeekabooError.windowNotFound(criteria: "windowId \(id)")
    }
}
