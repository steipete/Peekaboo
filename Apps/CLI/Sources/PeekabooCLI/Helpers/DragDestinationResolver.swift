import AppKit
import AXorcist
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
struct DragDestinationResolver {
    let services: any PeekabooServiceProviding

    func destinationPoint(forApplicationNamed appName: String) async throws -> CGPoint {
        if appName.lowercased() == "trash" {
            return try await self.findTrashPoint()
        }

        let appInfo = try await self.resolveApplication(appName)

        // Prefer the window-listing service path so tests and WindowServer-backed flows do not
        // require a live NSRunningApplication or AX window handle.
        do {
            let windowList = try await self.services.applications.listWindows(for: appInfo.name, timeout: nil)
            if let window = windowList.data.windows.first(where: { $0.isMainWindow })
                ?? windowList.data.windows.first {
                return CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            }
        } catch {
            // Fall back to AX-based window discovery below.
        }

        guard let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
            throw PeekabooError.appNotFound(appName)
        }

        let axApp = AXApp(runningApp)
        guard let windowElement = axApp.element.focusedWindow() ?? axApp.element.windows()?.first else {
            throw PeekabooError.windowNotFound(
                criteria: "No accessible window for \(appInfo.name)"
            )
        }

        guard let frame = windowElement.frame() else {
            throw PeekabooError.windowNotFound(
                criteria: "Window bounds unavailable for \(appInfo.name)"
            )
        }

        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func resolveApplication(_ identifier: String) async throws -> ServiceApplicationInfo {
        do {
            return try await self.services.applications.findApplication(identifier: identifier)
        } catch {
            if identifier.lowercased() == "frontmost" {
                throw PeekabooError.appNotFound(identifier)
            }
            throw error
        }
    }

    private func findTrashPoint() async throws -> CGPoint {
        guard let dock = self.findDockApplication(),
              let list = dock.children()?.first(where: { $0.role() == "AXList" })
        else {
            throw PeekabooError.elementNotFound("Dock not found")
        }

        let items = list.children() ?? []
        if let trash = items.first(where: { $0.label()?.lowercased() == "trash" }) {
            if let position = trash.position(), let size = trash.size() {
                return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
            }
        }

        throw PeekabooError.elementNotFound("Trash not found in Dock")
    }

    private func findDockApplication() -> Element? {
        let apps = NSWorkspace.shared.runningApplications
        guard let dockApp = apps.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            return nil
        }
        return AXApp(dockApp).element
    }
}
