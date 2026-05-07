import AXorcist
import Foundation

@MainActor
extension DialogService {
    func findActiveFileDialogElement(appName: String) -> Element? {
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
}
