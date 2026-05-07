import AXorcist
import CoreGraphics
import Foundation

@MainActor
extension DialogService {
    func findDialogUsingCGWindowList(title: String?) -> Element? {
        guard let cgWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID) as? [[String: Any]]
        else {
            return nil
        }

        for info in cgWindows {
            guard let ownerPid = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let windowTitle = (info[kCGWindowName as String] as? String) ?? ""

            if let expectedTitle = title,
               !windowTitle.localizedCaseInsensitiveContains(expectedTitle)
            {
                continue
            }

            if title == nil,
               !self.dialogTitleHints.contains(where: { windowTitle.localizedCaseInsensitiveContains($0) })
            {
                continue
            }

            guard let appElement = AXApp(pid: pid_t(ownerPid.intValue))?.element,
                  let windows = appElement.windowsWithTimeout(timeout: 0.5)
            else { continue }

            if let matchingWindow = windows.first(where: {
                let axTitle = $0.title() ?? ""
                return axTitle == windowTitle || self.isDialogElement($0, matching: title)
            }) {
                return matchingWindow
            }
        }

        return nil
    }
}
