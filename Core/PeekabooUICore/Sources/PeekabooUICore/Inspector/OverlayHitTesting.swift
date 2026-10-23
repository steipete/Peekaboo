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

    static func windowOrder(
        elementGroups: [(ownerPID: Int, frames: [CGRect])],
        onScreenFrontToBack: [(ownerPID: Int, bounds: CGRect)],
        frontmostPID: Int?) -> [Int]
    {
        guard !onScreenFrontToBack.isEmpty else {
            let front = elementGroups.indices.filter { elementGroups[$0].ownerPID == frontmostPID }
            let rest = elementGroups.indices.filter { elementGroups[$0].ownerPID != frontmostPID }
            return Array(front) + Array(rest)
        }
        var remaining = Set(elementGroups.indices)
        var ordered: [Int] = []
        for window in onScreenFrontToBack {
            guard let index = elementGroups.indices.first(where: { candidate in
                guard remaining.contains(candidate),
                      elementGroups[candidate].ownerPID == window.ownerPID,
                      let axFrame = elementGroups[candidate].frames.first
                else { return false }
                return self.sameWindow(axFrame, window.bounds)
            }) else { continue }
            remaining.remove(index)
            ordered.append(index)
        }
        let unmatchedFront = remaining.filter { elementGroups[$0].ownerPID == frontmostPID }.sorted()
        let unmatchedRest = remaining.subtracting(unmatchedFront).sorted()
        if ordered.isEmpty {
            return unmatchedFront + unmatchedRest
        }
        return ordered + unmatchedFront + unmatchedRest
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
