import AppKit
import AXorcist
import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

// MARK: - Action Extensions

extension Attribute where T == String {
    static var hide: Attribute<String> { Attribute("AXHide") }
    static var unhide: Attribute<String> { Attribute("AXUnhide") }
}

// MARK: - Application Finding

/// Async wrapper for finding applications using PeekabooCore services
@MainActor
func findApplication(
    identifier: String,
    services: any PeekabooServiceProviding
) async throws -> (app: Element, runningApp: NSRunningApplication) {
    // Use PeekabooServices to find the application
    let appInfo = try await services.applications.findApplication(identifier: identifier)

    // Get the NSRunningApplication
    guard let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
        throw PeekabooError.appNotFound(identifier)
    }

    let axApp = AXApp(runningApp)
    return (app: axApp.element, runningApp: runningApp)
}

// MARK: - Error Bridging

/// Commander emits its own `ValidationError` type; bridge it to the shared protocol so
/// test helpers (and callers) can pattern match on `any ValidationError` uniformly.
extension Commander.ValidationError: PeekabooFoundation.ValidationError {
    public var fieldName: String { "input" }
    public var failedRule: String { self.description }
    public var invalidValue: String? { nil }
    public var errorCode: String { "VALIDATION" }
}
