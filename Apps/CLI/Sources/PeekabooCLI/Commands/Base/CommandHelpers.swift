import AppKit
import ApplicationServices
import AXorcist
import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

// MARK: - Element Extensions for System UI

extension Element {
    @MainActor
    func menuBar() -> Element? {
        guard let menuBar = attribute(Attribute<AXUIElement>("AXMenuBar")) else {
            return nil
        }
        return Element(menuBar)
    }

    @MainActor
    static func systemWide() -> Element {
        Element(AXUIElementCreateSystemWide())
    }

    @MainActor
    func focusedApplication() -> Element? {
        guard let app = attribute(Attribute<AXUIElement>("AXFocusedApplication")) else {
            return nil
        }
        return Element(app)
    }
}

// MARK: - Action Extensions

extension Attribute where T == String {
    static var hide: Attribute<String> { Attribute("AXHide") }
    static var unhide: Attribute<String> { Attribute("AXUnhide") }
}

// MARK: - Application Finding

/// Async wrapper for finding applications using PeekabooCore services
@MainActor
func findApplication(identifier: String) async throws -> (app: Element, runningApp: NSRunningApplication) {
    // Use PeekabooServices to find the application
    let appInfo = try await PeekabooServices.shared.applications.findApplication(identifier: identifier)

    // Get the NSRunningApplication
    guard let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
        throw PeekabooError.appNotFound(identifier)
    }

    let element = Element(AXUIElementCreateApplication(runningApp.processIdentifier))
    return (app: element, runningApp: runningApp)
}
