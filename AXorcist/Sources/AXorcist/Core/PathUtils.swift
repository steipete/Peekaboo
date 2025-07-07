import Foundation

public enum PathUtils {
    public static func parsePathComponent(_ pathComponent: String) -> (attributeName: String, expectedValue: String) {
        let trimmedPathComponentString = pathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedPathComponentString.split(separator: ":", maxSplits: 1)

        guard parts.count == 2 else {
            // AXorcist's navigateToElement should handle this, e.g. by logging a CRITICAL_NAV_PARSE_FAILURE_MARKER
            // and returning nil from navigateToElement if attributeName is empty.
            return (attributeName: "", expectedValue: "")
        }
        return (attributeName: String(parts[0]), expectedValue: String(parts[1]))
    }
}
