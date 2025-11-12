import ApplicationServices
import Foundation

// GlobalAXLogger should be available

// Extension to generate a descriptive path string
public extension Element {
    @MainActor
    func generatePathString(upTo ancestor: Element? = nil) -> String { // Removed logging params
        var pathComponents: [String] = []
        var currentElement: Element? = self
        var depth = 0
        let maxDepth = 25

        // self.briefDescription and ancestor?.briefDescription now use GlobalAXLogger
        // Assumes self.briefDescription() has been refactored in Element+Description.swift
        let ancestorDesc = ancestor?.briefDescription(option: .smart) ?? "nil"
        let logMessage1 = """
        generatePathString started for element: \(self.briefDescription(option: .smart))
        upTo: \(ancestorDesc)
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        axDebugLog(logMessage1)

        while let element = currentElement, depth < maxDepth {
            // All calls to element.briefDescription(), element.role(), element.parent()
            // are now using their refactored, logger-less signatures.
            // Internal logging happens within those methods via GlobalAXLogger.
            // Assumes these methods are refactored in Element+Properties.swift and Element+Description.swift
            let briefDesc = element.briefDescription(option: .smart)
            pathComponents.append(briefDesc)

            if let ancestor, element == ancestor {
                axDebugLog("Reached specified ancestor: \(briefDesc)")
                break
            }

            let role = element.role()
            let parentElement = element.parent()
            let parentRole = parentElement?.role()

            if role == AXRoleNames.kAXApplicationRole ||
                (role == AXRoleNames.kAXWindowRole && parentRole == AXRoleNames.kAXApplicationRole && ancestor == nil)
            {
                let locationType = role == AXRoleNames.kAXApplicationRole ? "Application" : "Window under App"
                let logMessage2 = "Stopping at \(locationType): \(briefDesc)"
                axDebugLog(logMessage2)
                break
            }

            currentElement = parentElement
            depth += 1
            if currentElement == nil, role != AXRoleNames.kAXApplicationRole {
                let orphanLog = "< Orphaned element path component: \(briefDesc) (role: \(role ?? "nil")) >"
                axWarningLog("Unexpected orphan in path generation: \(orphanLog)") // Changed to warning
                pathComponents.append(orphanLog)
                break
            }
        }
        if depth >= maxDepth {
            axWarningLog("Reached max depth (\(maxDepth)) for path generation. Path might be truncated.")
            pathComponents.append("<...max_depth_reached...>")
        }

        let finalPath = pathComponents.reversed().joined(separator: " -> ")
        axDebugLog("generatePathString finished. Path: \(finalPath)")
        return finalPath
    }

    // New function to return path components as an array
    @MainActor
    func generatePathArray(upTo ancestor: Element? = nil) -> [String] { // Removed logging params
        var pathComponents: [String] = []
        var currentElement: Element? = self
        var depth = 0
        let maxDepth = 25

        let targetDesc = ancestor?.briefDescription(option: .smart) ?? "nil"
        let logMessage3 = """
        generatePathArray started for element: \(self.briefDescription(option: .smart))
        upTo: \(targetDesc)
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        axDebugLog(logMessage3)

        while let element = currentElement, depth < maxDepth {
            let briefDesc = element.briefDescription(option: .smart)
            let dump = element.dump()
            pathComponents.append(briefDesc)
            pathComponents.append(dump)

            if let ancestor, element == ancestor {
                axDebugLog("Reached specified ancestor: \(briefDesc)")
                break
            }

            let role = element.role()
            let parentElement = element.parent()
            let parentRole = parentElement?.role()

            if role == AXRoleNames.kAXApplicationRole ||
                (role == AXRoleNames.kAXWindowRole && parentRole == AXRoleNames.kAXApplicationRole && ancestor == nil)
            {
                let locationType = role == AXRoleNames.kAXApplicationRole ? "Application" : "Window under App"
                axDebugLog("Stopping at \(locationType): \(briefDesc)")
                break
            }

            currentElement = parentElement
            depth += 1
            if currentElement == nil, role != AXRoleNames.kAXApplicationRole {
                let orphanLog = "< Orphaned element path component: \(briefDesc) (role: \(role ?? "nil")) >"
                axWarningLog("Unexpected orphan in path generation: \(orphanLog)")
                pathComponents.append(orphanLog)
                break
            }
        }
        if depth >= maxDepth {
            axWarningLog("Reached max depth (\(maxDepth)) for path generation. Path might be truncated.")
            pathComponents.append("<...max_depth_reached...>")
        }

        let reversedPathComponents = Array(pathComponents.reversed())
        let summary = reversedPathComponents.joined(separator: "/")
        axDebugLog("generatePathArray finished. Path components: \(summary)")
        return reversedPathComponents
    }
}
