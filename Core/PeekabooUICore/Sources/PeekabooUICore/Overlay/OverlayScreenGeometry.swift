import CoreGraphics
import PeekabooFoundation

enum OverlayScreenGeometry {
    /// Accessibility frames use the primary display's upper-left origin.
    /// `primaryScreen` is that display in AppKit coordinates.
    static func swiftUICenter(
        for frame: CGRect,
        on screen: CGRect,
        primaryScreen: CGRect) -> CGPoint
    {
        let appKitCenter = GlobalScreenCoordinateGeometry.appKitPoint(
            fromGlobalDisplay: CGPoint(x: frame.midX, y: frame.midY),
            primaryScreenFrame: primaryScreen)
        return CGPoint(
            x: appKitCenter.x - screen.minX,
            y: screen.maxY - appKitCenter.y)
    }

    static func primaryFrame(in screens: [CGRect], fallback: CGRect) -> CGRect {
        screens.first { $0.origin == .zero } ?? fallback
    }
}
