import AppKit
import Foundation

@MainActor
extension DialogService {
    func runningApplication(matching identifier: String) -> NSRunningApplication? {
        let lowered = identifier.lowercased()
        return NSWorkspace.shared.runningApplications.first {
            if let name = $0.localizedName?.lowercased(),
               name == lowered || name.contains(lowered)
            {
                return true
            }
            if let bundle = $0.bundleIdentifier?.lowercased(),
               bundle == lowered || bundle.contains(lowered)
            {
                return true
            }
            return false
        }
    }
}
