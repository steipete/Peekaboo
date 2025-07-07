import ApplicationServices
import Foundation

// Extension to generate a descriptive path string
extension Element {
    @MainActor
    // Update signature to include logging parameters
    public func generatePathString(
        upTo ancestor: Element? = nil,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> String {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled && false {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }
        var pathComponents: [String] = []
        var currentElement: Element? = self

        var depth = 0 // Safety break for very deep or circular hierarchies
        let maxDepth = 25
        var tempLogs: [String] = [] // Temporary logs for calls within the loop

        dLog(
            "generatePathString started for element: \(self.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)) upTo: \(ancestor?.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) ?? "nil")"
        )

        while let element = currentElement, depth < maxDepth {
            tempLogs.removeAll() // Clear for each iteration
            let briefDesc = element.briefDescription(
                option: .default,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &tempLogs
            )
            pathComponents.append(briefDesc)
            currentDebugLogs.append(contentsOf: tempLogs) // Append logs from briefDescription

            if let ancestor = ancestor, element == ancestor {
                dLog("generatePathString: Reached specified ancestor: \(briefDesc)")
                break // Reached the specified ancestor
            }

            // Check role to prevent going above application or a window if its parent is the app
            tempLogs.removeAll()
            let role = element.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
            currentDebugLogs.append(contentsOf: tempLogs)

            tempLogs.removeAll()
            let parentElement = element.parent(
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &tempLogs
            )
            currentDebugLogs.append(contentsOf: tempLogs)

            tempLogs.removeAll()
            let parentRole = parentElement?.role(
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &tempLogs
            )
            currentDebugLogs.append(contentsOf: tempLogs)

            if role == AXRoleNames.kAXApplicationRole ||
                (role == AXRoleNames.kAXWindowRole && parentRole == AXRoleNames.kAXApplicationRole && ancestor == nil) {
                dLog(
                    "generatePathString: Stopping at \(role == AXRoleNames.kAXApplicationRole ? "Application" : "Window under App"): \(briefDesc)"
                )
                break
            }

            currentElement = parentElement
            depth += 1
            if currentElement == nil && role != AXRoleNames.kAXApplicationRole {
                let orphanLog = "< Orphaned element path component: \(briefDesc) (role: \(role ?? "nil")) >"
                dLog("generatePathString: Unexpected orphan: \(orphanLog)")
                pathComponents.append(orphanLog)
                break
            }
        }
        if depth >= maxDepth {
            dLog("generatePathString: Reached max depth (\(maxDepth)). Path might be truncated.")
            pathComponents.append("<...max_depth_reached...>")
        }

        let finalPath = pathComponents.reversed().joined(separator: " -> ")
        dLog("generatePathString finished. Path: \(finalPath)")
        return finalPath
    }

    // New function to return path components as an array
    @MainActor
    public func generatePathArray(
        upTo ancestor: Element? = nil,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> [String] {
        func dLog(_ message: String) { if isDebugLoggingEnabled && false { currentDebugLogs.append(message) } }
        var pathComponents: [String] = []
        var currentElement: Element? = self

        var depth = 0
        let maxDepth = 25
        var tempLogs: [String] = []

        dLog(
            "generatePathArray started for element: \(self.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)) upTo: \(ancestor?.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) ?? "nil")"
        )
        currentDebugLogs.append(contentsOf: tempLogs); tempLogs.removeAll()

        while let element = currentElement, depth < maxDepth {
            tempLogs.removeAll()
            let briefDesc = element.briefDescription(
                option: .default,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &tempLogs
            )
            pathComponents.append(briefDesc)
            currentDebugLogs.append(contentsOf: tempLogs); tempLogs.removeAll()

            if let ancestor = ancestor, element == ancestor {
                dLog("generatePathArray: Reached specified ancestor: \(briefDesc)")
                break
            }

            tempLogs.removeAll()
            let role = element.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
            currentDebugLogs.append(contentsOf: tempLogs); tempLogs.removeAll()

            tempLogs.removeAll()
            let parentElement = element.parent(
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &tempLogs
            )
            currentDebugLogs.append(contentsOf: tempLogs); tempLogs.removeAll()

            tempLogs.removeAll()
            let parentRole = parentElement?.role(
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &tempLogs
            )
            currentDebugLogs.append(contentsOf: tempLogs); tempLogs.removeAll()

            if role == AXRoleNames.kAXApplicationRole ||
                (role == AXRoleNames.kAXWindowRole && parentRole == AXRoleNames.kAXApplicationRole && ancestor == nil) {
                dLog(
                    "generatePathArray: Stopping at \(role == AXRoleNames.kAXApplicationRole ? "Application" : "Window under App"): \(briefDesc)"
                )
                break
            }

            currentElement = parentElement
            depth += 1
            if currentElement == nil && role != AXRoleNames.kAXApplicationRole {
                let orphanLog = "< Orphaned element path component: \(briefDesc) (role: \(role ?? "nil")) >"
                dLog("generatePathArray: Unexpected orphan: \(orphanLog)")
                pathComponents.append(orphanLog)
                break
            }
        }
        if depth >= maxDepth {
            dLog("generatePathArray: Reached max depth (\(maxDepth)). Path might be truncated.")
            pathComponents.append("<...max_depth_reached...>")
        }

        let reversedPathComponents = Array(pathComponents.reversed())
        dLog("generatePathArray finished. Path components: \(reversedPathComponents.joined(separator: "/"))") // Log for debugging
        return reversedPathComponents
    }
}
