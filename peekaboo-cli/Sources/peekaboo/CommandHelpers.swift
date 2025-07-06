import Foundation
import ApplicationServices
import AXorcist
import ArgumentParser
import AppKit

// MARK: - Verbose Protocol

/// Protocol for commands that support verbose logging
protocol VerboseCommand {
    var verbose: Bool { get }
}

extension VerboseCommand {
    /// Configure logger for verbose mode if enabled
    func configureVerboseLogging() {
        Logger.shared.setVerboseMode(verbose)
        if verbose {
            Logger.shared.verbose("Verbose logging enabled")
        }
    }
}

// MARK: - Common Error Handling

func handleApplicationError(_ error: ApplicationError, jsonOutput: Bool) {
    if jsonOutput {
        let errorCode: ErrorCode
        switch error {
        case .notFound:
            errorCode = .APP_NOT_FOUND
        case .ambiguous:
            errorCode = .AMBIGUOUS_APP_IDENTIFIER
        }
        
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: errorCode
            )
        )
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}

func handleGenericError(_ error: Error, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: .UNKNOWN_ERROR
            )
        )
        outputJSON(response)
    } else {
        print("❌ Error: \(error.localizedDescription)")
    }
}

func handleValidationError(_ error: Error, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: .VALIDATION_ERROR
            )
        )
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}

// MARK: - Element Extensions for System UI

extension Element {
    @MainActor
    func menuBar() -> Element? {
        guard let menuBar = self.attribute(Attribute<AXUIElement>("AXMenuBar")) else {
            return nil
        }
        return Element(menuBar)
    }
    
    @MainActor
    static func systemWide() -> Element {
        return Element(AXUIElementCreateSystemWide())
    }
    
    @MainActor
    func focusedApplication() -> Element? {
        guard let app = self.attribute(Attribute<AXUIElement>("AXFocusedApplication")) else {
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

/// Async wrapper for ApplicationFinder
@MainActor
func findApplication(identifier: String) async throws -> (app: Element, runningApp: NSRunningApplication) {
    let runningApp = try ApplicationFinder.findApplication(identifier: identifier)
    let element = Element(AXUIElementCreateApplication(runningApp.processIdentifier))
    return (app: element, runningApp: runningApp)
}