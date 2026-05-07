import AppKit
@preconcurrency import AXorcist

@MainActor
extension DockService {
    func findDockApplication() -> Element? {
        let workspace = NSWorkspace.shared
        guard let dockApp = workspace.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else {
            return nil
        }

        return AXApp(dockApp).element
    }

    func findDockElement(appName: String) throws -> Element {
        guard let dock = findDockApplication() else {
            throw DockError.dockNotFound
        }

        guard let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) else {
            throw DockError.dockListNotFound
        }

        let dockItems = dockList.children() ?? []

        if let exactMatch = dockItems.first(where: { $0.title() == appName }) {
            return exactMatch
        }

        let lowercaseAppName = appName.lowercased()
        if let match = dockItems.first(where: { item in
            guard let title = item.title() else { return false }
            return title.lowercased() == lowercaseAppName ||
                title.lowercased().contains(lowercaseAppName)
        }) {
            return match
        }

        throw DockError.itemNotFound(appName)
    }
}
