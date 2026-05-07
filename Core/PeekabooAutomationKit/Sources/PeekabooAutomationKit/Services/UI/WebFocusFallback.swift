@preconcurrency import AXorcist
import os.log

/// Focuses embedded web content when an initial AX traversal only exposes a sparse proxy tree.
@MainActor
struct WebFocusFallback {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "WebFocusFallback")

    func focusIfNeeded(window: Element, appElement: Element) -> Bool {
        guard let target = self.findWebArea(in: window) ?? self.findWebArea(in: appElement) else {
            return false
        }

        do {
            try target.performAction(.press)
            self.logger.debug("Focused AXWebArea to expose embedded web content")
            return true
        } catch {
            self.logger.error("Failed to focus AXWebArea: \(error.localizedDescription)")
            return false
        }
    }

    private func findWebArea(in element: Element, depth: Int = 0) -> Element? {
        guard depth < 6 else { return nil }

        let role = element.role()?.lowercased()
        let roleDescription = element.roleDescription()?.lowercased()
        if role == "axwebarea" || roleDescription?.contains("web area") == true {
            return element
        }

        guard let children = element.children(strict: depth >= 1) else { return nil }
        for child in children {
            if let found = self.findWebArea(in: child, depth: depth + 1) {
                return found
            }
        }
        return nil
    }
}
