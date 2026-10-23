import CoreGraphics
import PeekabooFoundation

enum OverlayHitTesting {
    /// Earliest frame wins when two positive areas are equal.
    /// A zero-area frame is not a hit, even when the point sits on its origin.
    static func smallestIndex(containing point: CGPoint, in frames: [CGRect]) -> Int? {
        var bestIndex: Int?
        var bestArea = CGFloat.greatestFiniteMagnitude
        for (index, frame) in frames.enumerated() {
            let rect = frame.standardized
            guard rect.width > 0, rect.height > 0, rect.contains(point) else { continue }
            let area = rect.width * rect.height
            if area < bestArea {
                bestArea = area
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// `windowsFrontToBack` is front to back. Each inner list starts with that window's frame.
    static func frontmostElementIndex(
        containing point: CGPoint,
        windowsFrontToBack: [[CGRect]]) -> (window: Int, element: Int)?
    {
        for (windowIndex, frames) in windowsFrontToBack.enumerated() {
            guard let windowFrame = frames.first?.standardized,
                  windowFrame.width > 0,
                  windowFrame.height > 0,
                  windowFrame.contains(point),
                  let elementIndex = smallestIndex(containing: point, in: frames)
            else { continue }
            return (windowIndex, elementIndex)
        }
        return nil
    }

    /// The flip in `GlobalScreenCoordinateGeometry` is symmetric, so an AppKit
    /// pointer comes back as an Accessibility point.
    static func accessibilityPoint(fromAppKit point: CGPoint, primaryScreen: CGRect?) -> CGPoint {
        GlobalScreenCoordinateGeometry.appKitPoint(
            fromGlobalDisplay: point,
            primaryScreenFrame: primaryScreen)
    }

    /// One entry of the front-to-back hover stack.
    enum HoverLayer: Equatable {
        /// An Accessibility element group, by index.
        case window(Int)
        /// A visible on-screen window with no element group. It hides whatever lies behind it.
        case occluder(CGRect)
    }

    static func windowOrder(
        elementGroups: [(ownerPID: Int, frames: [CGRect])],
        onScreenFrontToBack: [(ownerPID: Int, bounds: CGRect)],
        frontmostPID: Int?) -> [Int]
    {
        self.hoverLayers(
            elementGroups: elementGroups,
            onScreenFrontToBack: onScreenFrontToBack,
            frontmostPID: frontmostPID)
            .compactMap { layer in
                if case let .window(index) = layer {
                    index
                } else {
                    nil
                }
            }
    }

    static func hoverLayers(
        elementGroups: [(ownerPID: Int, frames: [CGRect])],
        onScreenFrontToBack: [(ownerPID: Int, bounds: CGRect)],
        frontmostPID: Int?) -> [HoverLayer]
    {
        func fallback(_ indices: Set<Int>) -> [HoverLayer] {
            let front = indices.filter { elementGroups[$0].ownerPID == frontmostPID }.sorted()
            let rest = indices.subtracting(front).sorted()
            return (front + rest).map { .window($0) }
        }
        guard !onScreenFrontToBack.isEmpty else {
            return fallback(Set(elementGroups.indices))
        }
        var remaining = Set(elementGroups.indices)
        var stack: [(group: Int?, window: (ownerPID: Int, bounds: CGRect))] = []
        for window in onScreenFrontToBack {
            let index = elementGroups.indices.first { candidate in
                guard remaining.contains(candidate),
                      elementGroups[candidate].ownerPID == window.ownerPID,
                      let axFrame = elementGroups[candidate].frames.first
                else { return false }
                return self.sameWindow(axFrame, window.bounds)
            }
            if let index {
                remaining.remove(index)
            }
            stack.append((index, window))
        }
        guard stack.contains(where: { $0.group != nil }) else {
            return fallback(remaining)
        }
        // Only windows of apps without any element group occlude (the Dock, the menu bar, untracked
        // apps). A tracked app's unmatched surfaces, such as popup menus whose items live in another
        // group or windows whose frames drifted, never hide anything.
        let trackedOwners = Set(elementGroups.map(\.ownerPID))
        let layers: [HoverLayer] = stack.compactMap { entry in
            if let group = entry.group {
                return .window(group)
            }
            return trackedOwners.contains(entry.window.ownerPID) ? nil : .occluder(entry.window.bounds)
        }
        return layers + fallback(remaining)
    }

    /// Walks the stack front to back. An occluder under the point means nothing behind it is hovered.
    static func hoveredElement(
        containing point: CGPoint,
        layers: [HoverLayer],
        groupFrames: [[CGRect]]) -> (group: Int, element: Int)?
    {
        for layer in layers {
            switch layer {
            case let .occluder(bounds):
                if bounds.standardized.contains(point) {
                    return nil
                }
            case let .window(group):
                guard groupFrames.indices.contains(group) else { continue }
                if let hit = self.frontmostElementIndex(containing: point, windowsFrontToBack: [groupFrames[group]]) {
                    return (group, hit.element)
                }
                // Descendants can extend past the window, such as a popup menu's items.
                let descendants = Array(groupFrames[group].dropFirst())
                if let index = self.smallestIndex(containing: point, in: descendants) {
                    return (group, index + 1)
                }
            }
        }
        return nil
    }

    /// Catalog bounds and Accessibility frames can disagree by a few points.
    /// A similar size is not enough: cascaded windows of the same size each
    /// contain the other's center.
    private static func sameWindow(_ axFrame: CGRect, _ catalogBounds: CGRect) -> Bool {
        let axRect = axFrame.standardized
        let catalog = catalogBounds.standardized
        let slop: CGFloat = 4
        return abs(axRect.origin.x - catalog.origin.x) < slop
            && abs(axRect.origin.y - catalog.origin.y) < slop
            && abs(axRect.width - catalog.width) < slop
            && abs(axRect.height - catalog.height) < slop
    }
}
