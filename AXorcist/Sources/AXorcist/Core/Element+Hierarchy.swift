import ApplicationServices
import Foundation

// GlobalAXLogger should be available

// MARK: - Element Hierarchy Logic

extension Element {
    @MainActor
    public func children(strict: Bool = false) -> [Element]? { // Added strict parameter
        // Logging for this top-level call
        // self.briefDescription() is assumed to be refactored and available
        axDebugLog("Getting children for element: \(self.briefDescription(option: .smart)), strict: \(strict)")

        var childCollector = ChildCollector() // ChildCollector will use GlobalAXLogger internally

        // print("[PRINT Element.children] Before collectDirectChildren for: \(self.briefDescription(option: .smart))")
        collectDirectChildren(collector: &childCollector)
        // print("[PRINT Element.children] After collectDirectChildren, collector has:
        // \(childCollector.collectedChildrenCount()) unique children.")

        // collectAlternativeChildren may be expensive, so respect `strict` flag there.
        if !strict {
            collectAlternativeChildren(collector: &childCollector)
        }

        // Always collect `AXWindows` when this element is an application. Some Electron apps only expose
        // the *front-most* window via `kAXChildrenAttribute`, while all other windows are available via
        // `kAXWindowsAttribute`.  Not including the latter caused our searches to remain inside the first
        // window (depth ≈ 37) and never reach hidden/background chat panes.  Fetching `AXWindows` every
        // time is cheap (<10 elements) and guarantees the walker can explore every window even during a
        // brute-force scan.
        collectApplicationWindows(collector: &childCollector)

        // Also collect AXFocusedUIElement. This exposes the single element (often a remote renderer proxy)
        // that currently has keyboard/accessibility focus – crucial for Electron/Chromium where the deep
        // subtree is not reachable through normal children. By adding it here the global traversal can
        // discover the focused textarea without requiring special path hinting.
        if self.role() == AXRoleNames.kAXApplicationRole {
            if let focusedUI: AXUIElement = attribute(Attribute(AXAttributeNames.kAXFocusedUIElementAttribute)) {
                axDebugLog("Added AXFocusedUIElement to children list for application root.")
                childCollector.addChildren(from: [focusedUI])
            }
        }

        // print("[PRINT Element.children] Before finalizeResults, collector has:
        // \(childCollector.collectedChildrenCount()) unique children.")
        let result = childCollector.finalizeResults()
        axDebugLog("Final children count: \(result?.count ?? 0)")
        return result
    }

    @MainActor
    private func collectDirectChildren(collector: inout ChildCollector) {
        axDebugLog("Attempting to fetch kAXChildrenAttribute directly.")

        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            self.underlyingElement,
            AXAttributeNames.kAXChildrenAttribute as CFString,
            &value
        )

        // self.briefDescription() is assumed to be refactored
        let selfDescForLog = self.briefDescription(option: .smart)

        if error == .success {
            if let childrenCFArray = value, CFGetTypeID(childrenCFArray) == CFArrayGetTypeID() {
                if let directChildrenUI = childrenCFArray as? [AXUIElement] {
                    axDebugLog(
                        "[\(selfDescForLog)]: Successfully fetched and cast " +
                            "\(directChildrenUI.count) direct children."
                    )
                    collector.addChildren(from: directChildrenUI)
                } else {
                    axDebugLog(
                        "[\(selfDescForLog)]: kAXChildrenAttribute was a CFArray but failed to cast " +
                            "to [AXUIElement]. TypeID: \(CFGetTypeID(childrenCFArray))"
                    )
                }
            } else if let nonArrayValue = value {
                axDebugLog(
                    "[\(selfDescForLog)]: kAXChildrenAttribute was not a CFArray. " +
                        "TypeID: \(CFGetTypeID(nonArrayValue)). Value: \(String(describing: nonArrayValue))"
                )
            } else {
                axDebugLog("[\(selfDescForLog)]: kAXChildrenAttribute was nil despite .success error code.")
            }
        } else if error == .noValue {
            axDebugLog("[\(selfDescForLog)]: kAXChildrenAttribute has no value.")
        } else {
            axDebugLog("[\(selfDescForLog)]: Error fetching kAXChildrenAttribute: \(error.rawValue)")
        }
    }

    @MainActor
    private func collectAlternativeChildren(collector: inout ChildCollector) {
        let alternativeAttributes: [String] = [
            AXAttributeNames.kAXVisibleChildrenAttribute, AXAttributeNames.kAXWebAreaChildrenAttribute,
            AXAttributeNames.kAXApplicationNavigationAttribute, AXAttributeNames.kAXApplicationElementsAttribute,
            AXAttributeNames.kAXBodyAreaAttribute, AXAttributeNames.kAXSplitGroupContentsAttribute,
            AXAttributeNames.kAXLayoutAreaChildrenAttribute, AXAttributeNames.kAXGroupChildrenAttribute,
            AXAttributeNames.kAXContentsAttribute, "AXChildrenInNavigationOrder",
            AXAttributeNames.kAXSelectedChildrenAttribute, AXAttributeNames.kAXRowsAttribute,
            AXAttributeNames.kAXColumnsAttribute, AXAttributeNames.kAXTabsAttribute,
        ]
        axDebugLog(
            "Using pruned attribute list (\(alternativeAttributes.count) items) " +
                "to avoid heavy payloads for alternative children."
        )

        for attrName in alternativeAttributes {
            collectChildrenFromAttribute(attributeName: attrName, collector: &collector)
        }
    }

    @MainActor
    private func collectChildrenFromAttribute(attributeName: String, collector: inout ChildCollector) {
        axDebugLog("Trying alternative child attribute: '\(attributeName)'.")
        // self.attribute() now uses GlobalAXLogger and returns T?
        if let childrenUI: [AXUIElement] = attribute(Attribute(attributeName)) {
            if !childrenUI.isEmpty {
                axDebugLog("Successfully fetched \(childrenUI.count) children from '\(attributeName)'.")
                collector.addChildren(from: childrenUI)
            } else {
                axDebugLog("Fetched EMPTY array from '\(attributeName)'.")
            }
        } else {
            // attribute() logs its own failures/nil results
            axDebugLog("Attribute '\(attributeName)' returned nil or was not [AXUIElement].")
        }
    }

    @MainActor
    private func collectApplicationWindows(collector: inout ChildCollector) {
        // self.role() now uses GlobalAXLogger and is assumed refactored
        if self.role() == AXRoleNames.kAXApplicationRole {
            axDebugLog("Element is AXApplication. Trying kAXWindowsAttribute.")
            // self.attribute() for .windows, assumed refactored
            if let windowElementsUI: [AXUIElement] = attribute(.windows) {
                if !windowElementsUI.isEmpty {
                    axDebugLog("Successfully fetched \(windowElementsUI.count) windows.")
                    collector.addChildren(from: windowElementsUI)
                } else {
                    axDebugLog("Fetched EMPTY array from kAXWindowsAttribute.")
                }
            } else {
                axDebugLog("Attribute kAXWindowsAttribute returned nil for Application element.")
            }
        }
    }
}

// MARK: - Child Collection Helper

/// Upper bound for how many children we will collect from a single element before we stop.  Some web
/// containers expose thousands of flattened descendants; 50 000 is high enough to reach any realistic
/// UI while still protecting against infinite recursion / runaway memory.
private let maxChildrenPerElement = 50000

private struct ChildCollector {
    // MARK: Public

    // New public method to get the count of unique children
    public func collectedChildrenCount() -> Int {
        uniqueChildrenSet.count
    }

    // MARK: Internal

    mutating func addChildren(from childrenUI: [AXUIElement]) { // Removed dLog param
        if limitReached { return }

        for childUI in childrenUI {
            if collectedChildren.count >= maxChildrenPerElement {
                if !limitReached {
                    axWarningLog(
                        "ChildCollector: Reached maximum children limit (\(maxChildrenPerElement)). " +
                            "No more children will be added for this element."
                    )
                    limitReached = true
                }
                break
            }

            let childElement = Element(childUI)
            if !uniqueChildrenSet.contains(childElement) {
                collectedChildren.append(childElement)
                uniqueChildrenSet.insert(childElement)
            }
        }
    }

    func finalizeResults() -> [Element]? { // Removed dLog param
        if collectedChildren.isEmpty {
            axDebugLog("ChildCollector: No children found after all collection methods.")
            return nil
        } else {
            axDebugLog("ChildCollector: Found \(collectedChildren.count) unique children.")
            return collectedChildren
        }
    }

    // MARK: Private

    private var collectedChildren: [Element] = []
    private var uniqueChildrenSet = Set<Element>()
    private var limitReached = false
}
