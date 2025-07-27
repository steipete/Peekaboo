import AppKit
import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore

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
    nonisolated(unsafe) static let hide = Attribute<String>("AXHide")
    nonisolated(unsafe) static let unhide = Attribute<String>("AXUnhide")
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